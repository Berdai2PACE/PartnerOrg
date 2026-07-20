based on https://www.pablogonzalez.io/how-to-schedule-run-all-tests-in-salesforce-with-github-actions-for-unlimited-salesforce-orgs-nothing-to-install/#6create-a-slack-app-and-get-the-api-token

to set up completely, 
* configure a slack app like this or use an existing one to add a new webhook https://docs.slack.dev/tools/slack-github-action/sending-techniques/sending-data-slack-incoming-webhook/
* create the secret SLACK_WEBHOOK_URL and SLACK_CHANNEL_ID
* push your secret for the org you want in the SFDXAUTHURL_ORG format
* populate a GH_TOKEN secret with a PAT containing the Read access to actions, code, and metadata and  Read and Write access to pull requests permissions on your repo
* change the test matrix in [the first job](../.github/workflows/ApexTestMonitoring/matrix-check-test-runs.yml) and [the second job](../.github/workflows/ApexTestMonitoring/matrix-schedule-test-runs.yml)
* adjust the cron expression to suite your need
* move the [files](https://github.com/Manu2pace/2paceRepoTemplate/blob/dc630d81142b4611acf8c9c8afb1010f40fd9719/.github/workflows/ApexTestMonitoring) [to the root workflow](https://github.com/Manu2pace/2paceRepoTemplate/blob/9b0875ae02086d846e1da016f5465580e3d53f61/.github/workflows) folder
* use either the `sf apex run test --suite-names DailySurveillance --result-format human > ./id.txt` or `sf apex run test --test-level RunLocalTests --result-format human > ./id.txt` to run only a test suite of passing tests or all tests based on the current testing state