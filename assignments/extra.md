# Set up a build and deploy pipeline for your stack

Create a single Bash script which builds, starts, tests, pushes and deploys your services. 

If anything fails along the way, interrupt the process. You can use `set -e` for this.

## Suggestions

- Create a "test" container which runs end-to-end tests: verify that the web application returns the correct response. You may use any tool for this (e.g. vanilla PHP, PHPUnit, Behat, etc.).
- Push only the images that have been tested.
