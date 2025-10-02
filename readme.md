# What is this?

This is a bash script and Java example code to create a TF2 server to run on the cloud provider Linode.

## Why would you want to do this?

Traditional hosting costs many dollars a month, whereas Linode costs only a few cents an hour ($0.02-$0.06).

## Who is this for?

People who want to have a TF2 server for themselves or their friends, but don't want to pay a lot of money for it. Technical knowledge is not required.

## How to use this

1. Set up a Linode account
2. Add the contents of [stackscript.bash](https://github.com/kyleflett/TF2CloudServers/blob/main/src/main/resources/stackscript.bash) to your Linode account, use Ubuntu 22.04 & **DEDICATED not SHARED** (untested on other OS versions but I'm sure it's fine)
    - *(**Optional**)* Modify the script to change server name, password, rcon password, etc.
3. Launch a server using the Linode UI and stackscript
4. Connect to the server with the IP from Linode
5. **TURN THE SERVER OFF WHEN YOU ARE DONE.** You will be charged for every hour the server is on, even if no one is using it.

## Power Users or Devs
- Create an API key with read/write permissions for Linodes
- Find the Stackscript ID from the Linode UI
- Use the example Java code to create and manage Linodes programmatically

## Additional Notes

**For those who've read this far:**

There is a lot of vestigial code in the script from when I was integrating everything with RGL. I am leaving it in case it's useful to someone, but you can mostly ignore.

Use **Dedicated** Linodes because shared ones have noisy neighbors and you can have a bad time.

**Maps are annoying.** I created a PR on the [docker image](https://github.com/melkortf/tf2-servers) to add support for the most common comp maps. For now, you will need to add your own maps to /maps in the container, or modify the dockerfile to add them during build.

**For power users:** I included some sample Java code to interact with the server via the Linode API. You could use something like this to automate server creation and deletion, do this at a mass scale, start your own company, whatever you want really.

**Other providers:** There are other good providers, specifically can shout out Kamatera and AWS (Fargate), they also work.