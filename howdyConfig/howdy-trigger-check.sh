#!/bin/bash
# Gate for Howdy in /etc/pam.d/sudo: success only when HOWDY_TERMINAL=1.
# Invoked by pam_exec so the next auth line (Howdy) only runs when the
# user opted in via the `sudof` wrapper. Plain `sudo` skips Howdy.
[[ "$HOWDY_TERMINAL" == "1" ]]
