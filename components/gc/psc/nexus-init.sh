#!/bin/bash

set -e
set -v

# Talk to the metadata server to get the project id
PROJECTID=$(curl -s "http://metadata.google.internal/computeMetadata/v1/project/project-id" -H "Metadata-Flavor: Google")

echo "Project ID: ${PROJECTID}"

# Install dependencies from yum
sudo yum install -y java-17-openjdk-devel git

mvn --version

# Clone the source repository.
git clone https://github.com/xxxxxx
cd getting-started-java/gce

# Build the .war file and rename.
# very important - by renaming the war to root.war, it will run as the root servlet.
mvn clean package -q
mv target/getting-started-gce-1.0-SNAPSHOT.war /opt/jetty/webapps/root.war

# Install logging monitor
curl -sSO https://dl.google.com/cloudagents/add-logging-agent-repo.sh
sudo bash add-logging-agent-repo.sh --also-install

# The service name has changed in Rocky Linux 9
sudo systemctl restart google-cloud-logging

echo "Startup Complete"
