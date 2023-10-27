require 'dotenv/load'
require 'json'
require 'selenium-webdriver'
require 'rest-client'

class CodewarsKataScraper
  API_ENDPOINT = 'https://www.codewars.com/api/v1/users/jmayheww/code-challenges/completed'
  LOCAL_REPO_PATH = ENV['LOCAL_REPO_PATH']
  STORED_KATAS_PATH = "#{LOCAL_REPO_PATH}/completed_kata.json"

  def initialize
    @codewars_username = ENV['CODEWARS_USERNAME']
    puts @codewars_username

    @codewars_password = ENV['CODEWARS_PASSWORD']
    puts @codewars_password

    @github_repo = ENV['GITHUB_REPO']

    @timeout = 20
    @log = []
    initialize_driver
  end

  def run
    login_to_codewars
    completed_kata_data = fetch_completed_katas
    existing_kata = fetch_existing_kata

    if existing_kata.empty?
      puts 'No existing katas found in local storage.'
      new_kata = completed_kata_data
    else
      new_kata = completed_kata_data.reject do |kata_data|
        exists = existing_kata.any? { |existing| existing['id'] == kata_data['id'] }
        puts "Checking if kata #{kata_data['name']} exists: #{exists}"
        exists
      end
      puts "Found #{new_kata.count} new katas."
    end

    if new_kata.any?
      new_kata.each do |kata_data|
        puts "Navigating to kata solutions for #{kata_data['name']}"
        view_kata_solutions(kata_data)
        kata_data['solutions'] = scrape_kata_solutions(kata_data)
      end

      all_katas = existing_kata + new_kata
      store_new_kata(all_katas)

      puts 'Successfully stored new katas.'

    else
      puts 'No new katas found.'
    end

    close_driver
  end

  private

  def initialize_driver
    options = Selenium::WebDriver::Chrome::Options.new

    # Set User-Agent header
    options.add_argument('user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36')

    # Handle cookies and sessions
    @driver = Selenium::WebDriver.for :chrome, options: options
    @driver.manage.timeouts.implicit_wait = 10
  end

  def close_driver
    @driver.quit
  end

  def login_to_codewars
    @driver.get('https://www.codewars.com/users/sign_in')
    email_input = @driver.find_element(id: 'user_email')
    password_input = @driver.find_element(id: 'user_password')
    sign_in_button = @driver.find_element(class: 'btn')

    email_input.send_keys(@codewars_username)
    password_input.send_keys(@codewars_password)
    sign_in_button.click

    # Wait for page to load completely
    wait = Selenium::WebDriver::Wait.new(timeout: @timeout)
    wait.until { @driver.execute_script('return document.readyState') == 'complete' }
  end

  def fetch_completed_katas
    response = RestClient.get("#{API_ENDPOINT}?page=0")
    JSON.parse(response.body)['data']
  end

  def scrape_kata_solutions(kata_data)
    solutions = []
    wait = Selenium::WebDriver::Wait.new(timeout: @timeout)
    kata_id = kata_data['id']
    completed_languages = kata_data['completedLanguages']

    completed_languages.each do |language|
      puts "Scraping solution for #{language}"
      solutions_url = "https://www.codewars.com/kata/#{kata_id}/solutions/#{language}/me"
      puts solutions_url
      @driver.get(solutions_url)

      begin
        @driver.manage.timeouts.implicit_wait = 10

        # Toggle description display
        toggle_selector = "sl-details#kata-details-description span[slot='summary']"
        toggle_element = @driver.find_element(css: toggle_selector)
        toggle_element.click

        # Scrape code content
        code_selector = 'div.js-result-group pre'
        wait.until { @driver.find_element(css: code_selector).displayed? }
        code_content = @driver.execute_script("return document.querySelector('#{code_selector}').textContent")
        puts "Code content: #{code_content}"

        # Scrape description content
        description_selector = 'sl-details#kata-details-description div#description p'
        wait.until { @driver.find_element(css: description_selector).displayed? }
        description_content = @driver.find_element(css: description_selector).text
        puts "Description content: #{description_content}"

        # Storing data
        solutions << { language: language, code: code_content, description: description_content }
      rescue Selenium::WebDriver::Error::TimeoutError
        puts "Timed out waiting for #{language} solution. Skipping this language."
      end
    end
    puts "solution: #{solutions}"
    solutions
  end

  def view_kata_solutions(kata_data)
    kata_id = kata_data['id']
    languages = kata_data['completedLanguages']

    languages.each do |language|
      solutions_url = "https://www.codewars.com/kata/#{kata_id}/solutions/#{language}/me"
      @driver.get(solutions_url)

      begin
        # Wait for a critical element to be visible, confirming page load
        wait = Selenium::WebDriver::Wait.new(timeout: @timeout)
        selector = '#shell_content'
        wait.until { @driver.find_element(css: selector).displayed? }
      rescue Selenium::WebDriver::Error::TimeoutError
        puts 'Timed out waiting for code solutions container to load. Skipping this language.'
        next
      end
    end
  end

  def fetch_existing_kata
    return [] unless File.exist?(STORED_KATAS_PATH)

    JSON.parse(File.read(STORED_KATAS_PATH))
  end

  def store_new_kata(katas)
    # Load existing katas or initialize an empty array
    existing_katas = File.exist?(STORED_KATAS_PATH) ? JSON.parse(File.read(STORED_KATAS_PATH)) : []

    combined_katas = existing_katas + katas
    File.write(STORED_KATAS_PATH, JSON.pretty_generate(combined_katas))
    katas.each { |kata| commit_and_push_to_git(kata) }
  end

  # commit and push each new json object to github

  def commit_and_push_to_git(kata)
    Dir.chdir(LOCAL_REPO_PATH) do
      unless Dir.exist?('.git')
        puts "The directory at #{LOCAL_REPO_PATH} is not a git repository. Exiting..."
        return
      end

      `git checkout main`
      `git pull origin main`

      puts "Committing changes for #{kata['name']}..."
      `git add #{STORED_KATAS_PATH}`
      `git commit -m "#{kata['name']} - #{kata['completedAt']}"`
      `git push origin main`
    end
  end
end

# Instantiate the scraper and run it
begin
  scraper = CodewarsKataScraper.new
  scraper.run
rescue StandardError => e
  puts "An error occurred: #{e.message}"
end
