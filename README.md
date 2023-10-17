**_ 🚀 Codewars Kata Scraper 🚀 _**

This is a simple scraper that will scrape all the katas from codewars.com and save them in a json file located in whichever directory you want to privately store them in.

## Installation 💾

1. Clone the repository
2. Make sure you have Ruby installed
3. Run `bundle install` to install the gem dependencies
4. Verify that you have another repository that you want to store the katas in for private use
5. Create a `.env` file in the root directory of the project
6. Add the following to the `.env` file:

```
CODEWARS_USERNAME=your_username
CODEWARS_PASSWORD=your_password
CODEWARS_KATA_REPO_PATH=path_to_your_kata_repo
```

7. Run `ruby codewars_sync.rb` to start the scraper
8. The scraper will run until it has scraped all the katas from your account and saved them in the json file
9. You can now use the json file to create a private kata repository

## Support and Contributions 🙏

Found an issue or have an improvement in mind? Bug reports and pull requests are warmly welcomed on GitHub.

## License 📝

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Disclaimer ⚠️

This project is for educational purposes only. It is not affiliated with Codewars in any way.

## Author 💻

- [**Joshua Mayhew**](https://www.joshmayhew.dev/) - [LinkedIn](https://www.linkedin.com/in/joshua-mayhew-dev/) - [GitHub](https://github.com/jmayheww)
