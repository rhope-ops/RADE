# Release and handover

This page has the steps for three tasks: make an engine release, check the release, and give RADE to a new person who decides (a handover). Each step names the screen where you do it. When a step tells you to write down a value, the step that uses the value names it again.

The description of a release (what the workflow does and what an app does with the release) is in [engine.md](engine.md) "How an app gets the engine". This page has only the steps. For help, use the Teams channel **RHOPE-OPS**.

## Make an engine release

Do these steps only after GitHub shows the engine pull request as **Merged**. That pull request sets the line `ENGINE_RELEASE = ` in **engine/rade_build.py** to the number of the new release. You must be signed in to GitHub with write access to the repository RADE.

1. In a browser, open `https://github.com/rhope-ops/RADE/blob/main/engine/rade_build.py`. You see the file **rade_build.py**. Go on.
2. On the page **rade_build.py**, find the line that starts with `ENGINE_RELEASE = `. You see a number on that line, for example `36`. Write down the number: it is the number of your release.
3. Open `https://github.com/rhope-ops/RADE/actions/workflows/release.yml`. You see the page of the workflow **release** with the button **Run workflow**. Go on.
4. On the page of the workflow **release**, click **Run workflow**. You see a small form with the list **Use workflow from** and the field **Release tag**. Go on.
5. In the list **Use workflow from**, select `main`. You see `Branch: main` in the list. Go on.
6. In the field **Release tag**, type `engine-v` and the number of your release, for example `engine-v36`. You see the tag in the field. Go on.
7. Click the green button **Run workflow**. You see a new run at the top of the list of runs. If it is not there, it shows after a page reload. Go on.
8. On the list of runs, look at the new run. Wait until the run stops: it shows a green check mark or a red cross (about 5 minutes). Do not start a second run until then.
9. If the run shows a green check mark, the release is made. Go on with "Check the release".
10. If the run shows a red cross, the release is not made. Click the run. You see the job **release** with a red cross. Go on.
11. Click the job **release**. You see the log of the job. Write down the line that starts with `FAIL`, or the last red line if no line starts with `FAIL`.
12. In the Teams channel **RHOPE-OPS**, send the line that you wrote down. You see your message in the channel. Do not start a second run. The task is complete: the release waits for a fix.

## Check the release

You need the number of your release: the number on the line `ENGINE_RELEASE = ` of **engine/rade_build.py** on main. Your tag is `engine-v` and that number.

1. Open `https://github.com/rhope-ops/RADE/releases`. You see the release **RADE engine** and your tag at the top. Go on.
2. Under that release, open **Assets**. You see the files **rade-engine.sha256** and **rade-engine.lock.json**. Go on.
3. If one of the two files is not there, send your tag in the Teams channel **RHOPE-OPS**. You see your message in the channel. Do not use the release. The task is complete.
4. On a computer with git and the GitHub command line tool `gh`, open a terminal. You see the prompt. Go on.
5. In the terminal, run `gh --version`. You see `gh version` and a number. The number must be 2.49.0 or higher (older versions have no `attestation` command). Go on.
6. If the number is lower than 2.49.0, install the newest `gh` from `https://cli.github.com`. You see the new number when you run `gh --version` again. Go on.
7. Run `gh auth status`. You see `Logged in to github.com`, or a text that you are not logged in. Go on.
8. If you are not logged in, run `gh auth login`. You see a question about the account type. Go on.
9. Answer the questions of `gh auth login` with these choices, in this order:
   1. At "Where do you use GitHub?", select `GitHub.com`.
   2. At the question about the protocol, select `HTTPS`.
   3. At "Authenticate Git with your GitHub credentials?", type `Y`.
   4. At "How would you like to authenticate GitHub CLI?", select `Login with a web browser`.
   5. Write down the one-time code that `gh` shows, then press **Enter**.
   6. On the web page that opens, type the one-time code.
   7. Sign in to GitHub on that page.
   You see `Logged in as` and your account in the terminal. Go on.
10. If a folder **rade-check** is in the terminal folder from an earlier check, delete it. You see the prompt. Go on.
11. Run `git clone https://github.com/rhope-ops/RADE rade-check`. You see `Cloning into 'rade-check'` and then the prompt. Go on.
12. Run `cd rade-check`. You see the prompt again. Go on.
13. Run `git checkout engine-v36`, but type your number in place of `36`. You see a note about a "detached HEAD", then `HEAD is now at` and a commit. Go on.
14. Run `gh attestation verify engine/rade_build.py --repo rhope-ops/RADE`. It checks that the release workflow of RADE signed the SHA-256 of this file. You see `Verification succeeded!` among the lines. Go on.
15. If you do not see `Verification succeeded!`, send all the lines in the Teams channel **RHOPE-OPS**. You see your message in the channel. Do not use the release. The task is complete.
16. Run `cd ..`. You see the prompt again. You can delete the folder **rade-check**. The task is complete.

## Hand over RADE to a new person

In these steps, "you" is the person who decides now. The repository belongs to the personal account **rhope-ops**, not to an organization. So a new person gets write access as a collaborator: they can merge pull requests and make releases. The settings of the repository stay with the account **rhope-ops**. A move of the repository to another owner changes every address (the page, the app locks), so these steps do not move it. Do not send a password, a token or a key in a message. The repository holds none of these, and a handover needs none.

1. In a message to the new person, ask for their GitHub account name and their Google e-mail address. You see their reply. Write down the name and the address.
2. On GitHub, signed in as **rhope-ops**, open `https://github.com/rhope-ops/RADE/settings/access`. GitHub can ask for your password first. You see the page **Collaborators**. Go on.
3. On the page **Collaborators**, do these actions:
   1. Click **Add people**. A dialog opens.
   2. Type the GitHub account name that you wrote down.
   3. Click that account in the list of matches.
   4. Click **Add** and the account name, to add it to this repository.
   You see the account on the page, with the text **Pending invite**. Go on.
4. In a message to the new person, ask them to accept the invitation in their GitHub notifications. An invitation ends after 7 days. You see your sent message. Go on.
5. On the page **Collaborators**, reload the page. Wait until the account of the new person shows without the text **Pending invite**. After 7 days with no change, the invitation ends: a new invitation is necessary.
6. In your Google Drive, open the master denylist file. It holds the names that the content check blocks. You see the file. Go on.
7. Share the file with the Google e-mail address that you wrote down, with the role **Viewer**. You see that address in the sharing list of the file. Do not put the file in the repository or in a chat with an agent. Go on.
8. On GitHub, open `https://github.com/rhope-ops/RADE/pulls?q=is%3Amerged`. You see the merged pull requests. The title of an engine pull request starts with `engine-v`. Go on.
9. Wait until a new engine pull request shows on that page. This can take days or weeks. Do not change your access until then.
10. Let the new person do all the steps under the heading "Make an engine release" while you watch. You see their run on the page of the workflow **release**. Wait until the run stops.
11. If their run shows a green check mark, the new person can make releases. You see the new release on the page **Releases**. The task is complete.
12. If their run shows a red cross, the new person sends the `FAIL` line in the Teams channel **RHOPE-OPS**. You see their message. The task is complete.
