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
read -p "Enter the project name (e.g., user-service): " project_name
main_class="${project_name^}Application"  # Capitalize first letter for the main class name

# Prompt for group (package structure)
read -p "Enter the group (e.g., com.example or co.name): " group

# Prompt for server port
read -p "Enter the server port (e.g., 8081): " server_port

# Prompt for Config Server port 
read -p "Enter the config server port: " config_server_port

# Prompt for Eureka server port 
read -p "Enter the Eureka server port: " eureka_port

# Initialize dependencies variable
dependencies="implementation 'org.springframework.boot:spring-boot-starter-web'"
db_dependencies=""
security_dependencies=""

# Function to prompt for and select dependencies
select_dependencies() {
    echo "Select additional dependencies (enter the number, or 'q' to quit):"
    echo "1. Database"
    echo "2. Lombok"
    echo "3. Security"
    echo "q. Quit"

    read -p "Enter your choice: " choice

    case $choice in
        1)
            echo "Select the database type:"
            echo "1. PostgreSQL"
            echo "2. MongoDB"
            echo "3. Spring Data JPA (no specific database)"
            read -p "Enter your choice: " db_choice

            case $db_choice in
                1)
                    db_dependencies="implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
                    implementation 'org.postgresql:postgresql'"
                    ;;
                2)
                    db_dependencies="implementation 'org.springframework.boot:spring-boot-starter-data-mongodb'"
                    ;;
                3)
                    db_dependencies="implementation 'org.springframework.boot:spring-boot-starter-data-jpa'"
                    ;;
                *)
                    echo "Invalid choice for database."
                    ;;
            esac
            ;;
        2)
            dependencies="${dependencies}
            implementation 'org.projectlombok:lombok'
            annotationProcessor 'org.projectlombok:lombok'"
            ;;
        3)
            echo "Select security dependencies:"
            echo "1. Spring Security"
            echo "2. OAuth2 Client"
            echo "3. OAuth2 Resource Server"
            echo "4. OAuth2 Authorization Server"
            read -p "Enter your choice: " sec_choice

            case $sec_choice in
                1)
                    security_dependencies="implementation 'org.springframework.boot:spring-boot-starter-security'"
                    ;;
                2)
                    security_dependencies="implementation 'org.springframework.boot:spring-boot-starter-oauth2-client'"
                    ;;
                3)
                    security_dependencies="implementation 'org.springframework.boot:spring-boot-starter-oauth2-resource-server'"
                    ;;
                4)
                    security_dependencies="implementation 'org.springframework.security:spring-security-oauth2-authorization-server:0.4.0'"
                    ;;
                *)
                    echo "Invalid choice for security."
                    ;;
            esac
            ;;
        q)
            return
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac

    select_dependencies
}

# Prompt for dependencies
select_dependencies

# Convert dots in group to slashes for directory structure
package_path=$(echo "$group" | tr '.' '/')

# Create project structure for User Service
create_project() {
    local project_name=$1
    local main_class=$2
    local dependencies=$3
    local db_dependencies=$4
    local security_dependencies=$5

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
    ${db_dependencies}
    ${security_dependencies}
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

# Create User Service
create_project "${project_name}" "${main_class}" "${dependencies}" "${db_dependencies}" "${security_dependencies}""implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client'""implementation 'org.springframework.cloud:spring-cloud-starter-config'"

# Configure User Service
cat << EOF > spring-micro-service/${project_name}/src/main/resources/application.yml
server:
  port: ${server_port}

spring:
  application:
    name: ${project_name}
  config:
    import: optional:configserver:http://localhost:${config_server_port}
  datasource:
    url: jdbc:postgresql://localhost:5432/userdb
    username: admin
    password: admin@123
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: true

eureka:
  client:
    serviceUrl:
      defaultZone: http://localhost:${eureka_port}/eureka/
EOF

echo "${project_name} project has been created and configured successfully."

