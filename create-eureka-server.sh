#!/bin/bash

set -euo pipefail

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Gradle is installed
if ! command_exists gradle; then
    echo "Gradle is not installed. Please install Gradle before running this script."
    exit 1
fi

# Prompt for project name
read -p "Enter the project name: " project_name
main_class="${project_name^}Application"  # Capitalize first letter for the main class name

# Prompt for group (package structure)
read -p "Enter the group (e.g., com.example or co.name): " group

# Convert dots in group to slashes for directory structure
package_path=$(echo "$group" | tr '.' '/')

# Create project structure
create_project() {
    local project_name=$1
    local main_class=$2
    local dependencies=$3

    mkdir -p "spring-micro-service/${project_name}"
    cd "spring-micro-service/${project_name}"

    # Create build.gradle
    cat << EOF > build.gradle
plugins {
    id 'org.springframework.boot' version '3.1.3'
    id 'io.spring.dependency-management' version '1.1.3'
    id 'java'
}

group = '${group}'
version = '0.0.1-SNAPSHOT'
sourceCompatibility = '17'

repositories {
    mavenCentral()
}

ext {
    set('springCloudVersion', "2022.0.4")
}

dependencies {
    ${dependencies}
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
}

dependencyManagement {
    imports {
        mavenBom "org.springframework.cloud:spring-cloud-dependencies:\${springCloudVersion}"
    }
}

tasks.named('test') {
    useJUnitPlatform()
}
EOF

    # Create main application class
    mkdir -p src/main/java/${package_path}/${project_name//-/}
    cat << EOF > src/main/java/${package_path}/${project_name//-/}/${main_class}.java
package ${group}.${project_name//-/};

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class ${main_class} {
    public static void main(String[] args) {
        SpringApplication.run(${main_class}.class, args);
    }
}
EOF

    mkdir -p src/main/resources
    touch src/main/resources/application.yml

    cd ../..
}

# Create spring-micro-service folder if it doesn't exist
mkdir -p spring-micro-service

# Create Eureka Server
create_project "${project_name}" "${main_class}" "implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-server'"

# Configure Eureka Server
cat << EOF > spring-micro-service/${project_name}/src/main/resources/application.yml
spring:
  application:
    name: ${project_name}
  profiles:
    active: dev
server:
  port: 8761

eureka:
  instance:
    hostname: localhost
  client:
    registerWithEureka: false
    fetchRegistry: false
    serviceUrl:
      defaultZone: http://\${eureka.instance.hostname}:\${server.port}/eureka/
  server:
    waitTimeInMsWhenSyncEmpty: 0
    response-cache-update-interval-ms: 5000

management:
  endpoints:
    web:
      exposure:
        include: '*'
EOF

# Update main application class
sed -i.bak '/@SpringBootApplication/a\
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;\
\
@EnableEurekaServer' spring-micro-service/${project_name}/src/main/java/${package_path}/${project_name//-/}/${main_class}.java
rm spring-micro-service/${project_name}/src/main/java/${package_path}/${project_name//-/}/${main_class}.java.bak

echo "Eureka Server project has been created and configured successfully."
