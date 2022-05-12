#!/bin/bash -xe

# If the script is having problems the log of this will be located at
# /var/log/cloud-init-output.log
# tail -1000 /var/log/cloud-init-output.log  > newLogfile

sudo su

yum update -y

touch ~/.bashrc

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash
. /.nvm/nvm.sh
nvm install node
nvm install 16
npm set registry=https://registry.npmjs.org/
nvm use 16
npm install -g yarn

yum install git -y
npm install -g pm2 # don't use yarn here

mkdir -p /usr/app
cd /usr/app

git clone https://github.com/visual-regression-testing/web-server
cd web-server
git checkout origin/test # todo should be main # this is testing

# required for Next to build properly
echo "GITHUB_ID=${GITHUB_ID}" >> .env
echo "GITHUB_SECRET=${GITHUB_SECRET}" >> .env
# required for prod build
echo "NEXTAUTH_SECRET=${NEXTAUTH_SECRET}" >> .env
# gets the public IP since we don't know it at time of starting the EC2 server and can't pass it in
echo "NEXTAUTH_URL=http://$(curl ifconfig.me)" >> .env

yarn install
yarn build

pm2 start npm --name "web-server" -- start

sudo amazon-linux-extras install nginx1 -y

echo "server {
          listen 80;
          server_name nextjs.your-site.com;
      location / {
              proxy_pass http://127.0.0.1:3000;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
              proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto \$scheme;
          }
      }" > /etc/nginx/conf.d/your-site.conf

systemctl start nginx
