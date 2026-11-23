# Release and handover

This page has the steps for three tasks: make an engine release, check the release, and give RADE to a new person who decides (a handover). Each step names the screen where you do it. Read each value from the screen at the time of the step.

The description of a release (what the workflow does and what an app does with the release) is in [engine.md](engine.md) "How an app gets the engine". This page has only the steps.

## Make an engine release

Do these steps only after the engine pull request is merged into **main**.

1. In a browser, open `https://github.com/rhope-ops/RADE/blob/main/engine/rade_build.py`. You see the file **rade_build.py**. Go on.
2. On the page **rade_build.py**, find the line that starts with `ENGINE_RELEASE = `. You see a number on that line (for example `36`). Write down the number.
3. Open `https://github.com/rhope-ops/RADE/actions/workflows/release.yml`. You see the page **release** with the button **Run workflow**. Go on.
4. On the page **release**, click **Run workflow**. You see the boxes **Use workflow from** and **Release tag**. Go on.
5. In the box **Use workflow from**, select `main`. You see `Branch: main` in the box. Go on.
6. In the box **Release tag**, type `engine-v` and the number from the line `ENGINE_RELEASE = ` (for example `engine-v36`). You see the tag in the box. Go on.
7. Click the green button **Run workflow**. You see a new run at the top of the list. Wait until the run shows a green check mark (about 5 minutes). Do not start a second run until then.
8. If the run shows a red cross, open the log of the run. You see the lines of the run. Write down the line that starts with `FAIL`.
9. If you wrote down a `FAIL` line, send it in the Teams channel. You see your message in the channel. Do not start a second run. The task is complete.
10. If the run shows a green check mark, open `https://github.com/rhope-ops/RADE/releases`. You see the new release at the top. Go on.

## Check the release

1. On the page **Releases**, find the release **RADE engine engine-v** with your number. You see the list **Assets** under it. Go on.
2. Under **Assets**, find the files **rade-engine.sha256** and **rade-engine.lock.json**. You see both file names. Go on.
3. If one of the two files is not there, send the release name in the Teams channel. You see your message in the channel. The task is complete.
4. On a computer with the GitHub command line tool `gh`, open a terminal in a copy of the repository RADE. You see the prompt. Go on.
5. In the terminal, run `git fetch --tags`. You see the prompt again. Go on.
6. Run `git checkout engine-v36`, with your number in place of `36`. You see `HEAD is now at` and a commit. Go on.
7. Run `gh attestation verify engine/rade_build.py --repo rhope-ops/RADE`. You see `Verification succeeded!`. Go on.
8. If you see a text other than `Verification succeeded!`, send it in the Teams channel. You see your message in the channel. Go on.
9. Run `git checkout main`. You see `Switched to branch 'main'`. The task is complete.

## Hand over RADE to a new person

The person who decides now does these steps with the new person. The new person needs a GitHub account. Do not send a password, a token or a key in a message. The repository holds none of these, and a handover needs none.

1. On GitHub, open `https://github.com/rhope-ops/RADE/settings/access`. You see the page **Collaborators and teams**. Go on.
2. On the page **Collaborators and teams**, do these actions:
   1. Click **Add people**.
   2. Type the GitHub account name of the new person.
   3. Select the role **Admin**.
   You see the account in the list, with the text **Pending invite**. Go on.
3. Tell the new person to accept the invitation in their GitHub notifications. Wait until the list shows the account with the role **Admin**. Do not remove your own access until then.
4. Let the new person make the next engine release while you watch. You see a green check mark on the run. Go on.
5. Give the new person the master name list of the personal-data guard. You see their reply that they have the list. Do not put the list in the repository or in a chat with an agent. Go on.
6. On the page **Collaborators and teams**, change your own role. You see the new role next to your account. The task is complete.
