#!/bin/bash

# curl -sSL https://raw.githubusercontent.com/chihqiang/sh/main/git/user.sh | bash -s github

case "$1" in
  github-actions)
    user="github-actions[bot]"
    email="41898282+github-actions[bot]@users.noreply.github.com"
    ;;
  cnb)
    user="zhiqiang"
    email="eCIr200kcdcRjB6TDaNE4G+zhiqiang@noreply.cnb.cool"
    ;;
  github)
    user="zhiqiang"
    email="40115555+chihqiang@users.noreply.github.com"
    ;;
  gitee)
    user="zhiqiang"
    email="340157+zhiqiangwang@user.noreply.gitee.com"
    ;;
  *)
    echo "Unknown argument. Use one of: github-actions, cnb, github, gitee"
    exit 1
    ;;
esac

echo "Set user: $user"
git config user.name "$user"
echo "Set email: $email"
git config user.email "$email"
