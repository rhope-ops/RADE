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
5. In the terminal, run `gh auth status`. You see `Logged in to github.com`, or a text that you are not logged in. Go on.
6. If you are not logged in, run `gh auth login` and do what it asks. You see `Logged in as` and your account. Go on.
7. Run `git clone https://github.com/rhope-ops/RADE rade-check`. You see `Cloning into 'rade-check'` and then the prompt. Go on.
8. Run `cd rade-check`. You see the prompt again. Go on.
9. Run `git checkout engine-v36`, but type your number in place of `36`. You see a note about a "detached HEAD", then `HEAD is now at` and a commit. Go on.
10. Run `gh attestation verify engine/rade_build.py --repo rhope-ops/RADE`. It checks that the release workflow of RADE signed the SHA-256 of this file. You see `Verification succeeded!` among the lines. Go on.
11. If you do not see `Verification succeeded!`, send all the lines in the Teams channel **RHOPE-OPS**. You see your message in the channel. Do not use the release. The task is complete.
12. Run `cd ..`. You see the prompt again. You can delete the folder **rade-check**. The task is complete.

## Hand over RADE to a new person

In these steps, "you" is the person who decides now. The new person needs a GitHub account. Do not send a password, a token or a key in a message. The repository holds none of these, and a handover needs none.

1. On GitHub, open `https://github.com/rhope-ops/RADE/settings/access`. GitHub can ask for your password first. You see the page **Collaborators and teams**. Go on.
2. On the page **Collaborators and teams**, do these actions:
   1. Click **Add people**. A dialog opens.
   2. Type the GitHub account name of the new person.
   3. Click the account in the list of matches.
   4. Select the role **Admin**.
   5. Click the button that adds the account to the repository.
   You see the account on the page, with the text **Pending invite**. Go on.
3. In a message to the new person, ask them to accept the invitation in their GitHub notifications. You see your sent message. Go on.
4. On the page **Collaborators and teams**, reload the page. Wait until you see the account of the new person with the role **Admin**. Do not change your own role until then.
5. Wait until GitHub shows the next engine pull request as **Merged**. Then let the new person do the steps of "Make an engine release" while you watch. You see a green check mark on their run. Go on.
6. In your Google Drive, share the master name list of the personal-data guard (the denylist file) with the new person. You see the new person in the sharing list of that file. Do not put the file in the repository or in a chat with an agent. Go on.
7. On the page **Collaborators and teams**, change your own role to the role that you and the new person agreed on. You see that role next to your account. The task is complete.
