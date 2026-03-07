#!/bin/bash
# Setup GitHub deploy key for chancejiang/zeroclaw

mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Create the deploy key
cat > ~/.ssh/github-deploy << 'KEYEOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACAlSda5qEeRbfWIjXwsSV+5NYo9dm28fogrPKX59w8KuQAAAJC7mOnZu5jp
2gAAAAtzc2gtZWQyNTUxOQAAACAlSda5qEeRbfWIjXwsSV+5NYo9dm28fogrPKX59w8KuQ
AAAEDjd1I1X+PyJGvSbAWqF5fg6e7M5ZP3JDHGP2XvMKMmbCVJ1rmoR5Ft9YiNfCxJX7k1
ijx2jbx+iCs8pfn3Dwq5AAAACGdpdGh1Yi1kZXBsb3kB
-----END OPENSSH PRIVATE KEY-----
KEYEOF

chmod 600 ~/.ssh/github-deploy

# Create SSH config for GitHub
cat >> ~/.ssh/config << 'CONFIGEOF'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github-deploy
    IdentitiesOnly yes
CONFIGEOF

chmod 600 ~/.ssh/config

echo "GitHub deploy key installed"