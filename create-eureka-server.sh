#!/bin/bash

set -euo pipefail

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to convert hyphenated string to CamelCase
to_camel_case() {
    echo "$1" | sed -r 's/(^|-)([a-z])/\U\2/g'
}

# Check if Gradle is installed
if ! command_exists gradle; then
    echo "Gradle is not installed. Please install Gradle before running this script."
    exit 1
fi

# Prompt for project name and set a default if none is provided
read -p "Enter the project name (default: eureka-server): " project_name
project_name=${project_name:-eureka-server}  # Default to 'eureka-server' if no input is given

# Convert project name to lowercase with hyphens for directories and application name
project_name_lower=$(echo "$project_name" | sed 's/\([a-z0-9]\)\([A-Z]\)/\1-\2/g' | tr '[:upper:]' '[:lower:]')

# Convert hyphenated project name to CamelCase for the main class
project_name_camel=$(to_camel_case "$project_name")
main_class="${project_name_camel}Application"  # CamelCase + Application suffix

# Prompt for group (package structure)
read -p "Enter the group (e.g., com.example or co.name): " group

# Convert dots in group to slashes for directory structure
package_path=$(echo "$group" | tr '.' '/')

# Create project structure
create_project() {
    local project_name_lower=$1
    local main_class=$2
    local dependencies=$3

    mkdir -p "spring-micro-service/${project_name_lower}"
    cd "spring-micro-service/${project_name_lower}"

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
    mkdir -p src/main/java/${package_path}/${project_name_lower//-/}
    cat << EOF > src/main/java/${package_path}/${project_name_lower//-/}/${main_class}.java
package ${group}.${project_name_lower//-/};

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;

@SpringBootApplication
@EnableEurekaServer
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
create_project "${project_name_lower}" "${main_class}" "implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-server'"

# Configure Eureka Server
cat << EOF > spring-micro-service/${project_name_lower}/src/main/resources/application.yml
spring:
  application:
    name: ${project_name_lower}
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

# Create Dockerfile for the Eureka Server project
cat << EOF > spring-micro-service/${project_name_lower}/Dockerfile
# Use official OpenJDK image as the base image
FROM openjdk:17-jdk-alpine

# Set the working directory in the container
WORKDIR /app

# Copy the build.gradle and gradle wrapper files to the container
COPY build.gradle .
COPY gradlew .
COPY gradle ./gradle

# Copy the source code to the container
COPY src ./src

# Copy other necessary files
COPY settings.gradle .

# Download the necessary dependencies for the project
RUN ./gradlew build --no-daemon

# Copy the JAR file into the container
COPY build/libs/*.jar app.jar

# Expose the port that the application will run on
EXPOSE 8761

# Run the Spring Boot application
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF

echo "Eureka Server project and Dockerfile have been created and configured successfully."

