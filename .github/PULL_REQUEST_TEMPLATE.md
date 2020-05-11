<!---
If you haven't done so already, please read the CONTRIBUTING.md file to learn
how we work and what we expect from all contributors.

https://github.com/openSUSE/open-build-service/blob/master/CONTRIBUTING.md

In order to make it as easy as possible for other developers to review your
pull request we ask you to:

- Explain what this PR is about in the description
- Explain the steps the reviewer has to follow to verify your change
- If the reviewer needs sample data to verify your change, please explain how to
  create that data
- If you include visual changes in this PR, please add screenshots or GIFs
- If you address performance in this PR, add benchmark data or explain how the
  reviewer can benchmark this

This is a good PR description example:

Hey Friends,

this introduces labels for the different build result states on the project
monitor page. This makes it easier to get a visual overview of what is going on
in your project.

To verify this feature

- Enable the interconnect to build.opensuse.org
- Create the project home:Admin
- Add 'openSUSE Tumbleweed' as a repository to the project
- Branch a couple of packages into the project:
  ```
  for i in `osc -A http://0.0.0.0:3000 ls openSUSE.org:home:hennevogel`; do osc -A http://0.0.0.0:3000 copypac openSUSE.org:home:hennevogel $i home:Admin; done
  ```
- Visit the monitor page and see the new labels for the different states.

Here is a screenshot of how it looks:

** Before **
![Screenshot of the project monitor](https://example.com/screenshot1.png)

** After **
![Screenshot of the project monitor](https://example.com/screenshot2.png)

-->
