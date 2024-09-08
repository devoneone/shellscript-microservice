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

# Prompt for project name and convert it to lowercase with hyphens
read -p "Enter the project name (e.g., ProductService): " project_name
project_name_lower=$(echo "$project_name" | sed 's/\([a-z0-9]\)\([A-Z]\)/\1-\2/g' | tr '[:upper:]' '[:lower:]')
main_class="${project_name^}Application"  # Capitalize first letter for the main class name

# Prompt for group (package structure)
read -p "Enter the group (e.g., com.example or co.name): " group

# Prompt for server port
read -p "Enter the server port (e.g., 8081): " server_port

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

# Create project structure for the microservice
create_project() {
    local project_name=$1
    local main_class=$2
    local dependencies=$3
    local db_dependencies=$4
    local security_dependencies=$5

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
    mkdir -p src/main/java/${package_path}/${project_name_lower//-/}
    cat << EOF > src/main/java/${package_path}/${project_name_lower//-/}/${main_class}.java
package ${group}.${project_name_lower//-/};

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
    cd ../..
}

# Create spring-micro-service folder if it doesn't exist
mkdir -p spring-micro-service

# Check if the server-config folder exists in the spring-micro-service folder, if not create it
if [ ! -d "spring-micro-service/server-config" ]; then
    mkdir spring-micro-service/server-config
fi

# Create project-specific folder inside server-config
mkdir -p "spring-micro-service/server-config/${project_name_lower}"

# Create project files
create_project "${project_name_lower}" "${main_class}" "${dependencies}" "${db_dependencies}" "${security_dependencies}"

# Add the requested configuration to application.yml
cat << EOF > spring-micro-service/${project_name_lower}/src/main/resources/application.yml
spring:
  application:
    name: ${project_name_lower}
  profiles:
    active: dev  # Default active profile
  config:
    import: optional:configserver:\${CONFIG_SERVER_URL:http://config-server:8888}
  jpa:
    database-platform: org.hibernate.dialect.PostgreSQLDialect
    show-sql: true

server:
  port: \${SERVER_PORT:8081}

eureka:
  client:
    serviceUrl:
      defaultZone: \${EUREKA_SERVER_URL:http://eureka-server:8761/eureka}
EOF

cat << EOF > spring-micro-service/server-config/${project_name_lower}/${project_name_lower}-dev.yml
spring:
  datasource:
    url: jdbc:postgresql://postgres:5432/userdb
    username: admin
    password: admin@123
  jpa:
    database-platform: org.hibernate.dialect.PostgreSQLDialect
    hibernate:
      ddl-auto: update
    show-sql: true
server:
  port: ${server_port}
eureka:
  client:
    serviceUrl:
      defaultZone: http://eureka-server:8761/eureka
user:
  test:
    property: dev-value
EOF

cat << EOF > spring-micro-service/server-config/${project_name_lower}/${project_name_lower}-prod.yml
spring:
  config:
    activate:
      on-profile: prod
  datasource:
    url: jdbc:postgresql://postgres:5432/postgres
    username: admin
    password: admin@123
  jpa:
    hibernate:
      ddl-auto: validate
server:
  port: ${server_port}
eureka:
  client:
    serviceUrl:
      defaultZone: http://eureka-server:8761/eureka/
user:
  test:
    property: prod-value
EOF

cat << EOF > spring-micro-service/server-config/${project_name_lower}/${project_name_lower}.yml
spring:
  application:
    name: ${project_name_lower}
  jpa:
    database: POSTGRESQL
    show-sql: true
    properties:
      hibernate:
        format_sql: true
user:
  test:
    property: initial-value
EOF

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

# Build the project
RUN ./gradlew build --no-daemon

# Copy the JAR file into the container
COPY build/libs/*.jar app.jar

# Expose the port that the application will run on
EXPOSE ${server_port}

# Run the Spring Boot application
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF

echo "${project_name_lower} project and config files have been created and configured successfully."

