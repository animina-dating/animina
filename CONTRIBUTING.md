# Contributing to Animina

So you're interested in contributing to Animina. We are looking forward
for your input. Thank you!

## Understand the License

First thing to know, Animina is not a side project. For this reason, we 
have licensed this software under the 
[Functional Source License](https://fsl.software/), a
mostly permissive non-compete license that converts to Apache 2.0 or MIT 
after two years.

So, it's not strictly OSS, but it _will_ be. You're free to contribute,
but you can't take this and use it to compete with us. You can, however,
otherwise use it however you want.

It is the best of both worlds. Nobody can compete with us right away but 
it will be MIT in two years.

## Our Development Process

It's possible that you want to see a feature, and we disagree, so if you want
to get something accepted, please discuss it with us first, so we can all be
fairly confident that your work has a chance to be accepted before you spend
your time or result in needing to maintain a fork.

Please send an email to Stefan Wintermeyer <sw@wintermeyer-consulting.de>

## Submitting a Bug Report

You probably know how to submit a bug report.

You know, check first to see if something is already there, give us detail to
recreate it if at all possible. Things you would want you to do if you were
maintaining this project.

## Submitting a Change

If you talked it over with us, and we agree that it's something we would take,
please do the familiar GitHub dance of forking the repository and submitting
a Pull Request, so we can review and possibly merge it.

Any contributions sent to us implicitly give us the right to redistribute that
work under the same license and rights.

[Why we don't explicitly require a CLA for contributions to Animina](https://ben.balter.com/2018/01/02/why-you-probably-shouldnt-add-a-cla-to-your-open-source-project/)

### Misc Tooling

Make sure to always run the following commands before any commit:

- `mix format`
- `mix credo`
- `mix dialyzer`
- `mix test`

The same commands will be run by the GitHub CI and will stop any
Pull-Request if an error occurs.

### Git Hooks

Run the `./setup-hooks.sh` script to install the git hooks. If
you don't use those hooks: Please have a look into the script to see
what we expect befor commiting code to the repo.
