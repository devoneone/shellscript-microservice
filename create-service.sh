#!/bin/bash

set -euo pipefail

# Track which services were created
declare -A services

# Function to display the menu and handle user input
show_menu() {
    echo "Create Spring Services"
    echo "1. Eureka Service"
    echo "2. API Gateway"
    echo "3. Config Server"
    echo "4. User Service"
    echo "5. Exit and Generate Docker Compose"
    read -p "Please select an option [1-5]: " option
}

# Function to run the selected service creation script
run_script() {
    case "$1" in
        1)
            echo "Running Eureka Service setup..."
            ./create-eureka-server.sh
            services["eureka-server"]=1
            ;;
        2)
            echo "Running API Gateway setup..."
            ./create-api-gateway.sh
            services["api-gateway"]=1
            ;;
        3)
            echo "Running Config Server setup..."
            ./create-config-server.sh
            services["config-server"]=1
            ;;
        4)
            echo "Running User Service setup..."
            ./create-user-service.sh
            services["user-service"]=1
            ;;
        5)
            echo "Exiting and generating Docker Compose file..."
            generate_compose_file
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose a number between 1 and 5."
            ;;
    esac
}

# Function to generate the docker-compose.yml file
generate_compose_file() {
    compose_file="spring-micro-service/docker-compose.yml"

    echo "version: '3.8'" > "$compose_file"
    echo "" >> "$compose_file"
    echo "services:" >> "$compose_file"

    # Add services to the docker-compose file based on user selections
    if [[ ${services["eureka-server"]+1} ]]; then
        cat << EOF >> "$compose_file"
  eureka-server:
    build:
      context: ./eureka-server
      dockerfile: Dockerfile
    ports:
      - "8761:8761"
    environment:
      - SPRING_PROFILES_ACTIVE=dev
    networks:
      - spring-cloud-network

EOF
    fi

    if [[ ${services["config-server"]+1} ]]; then
        cat << EOF >> "$compose_file"
  config-server:
    build:
      context: ./config-server
      dockerfile: Dockerfile
    ports:
      - "8888:8888"
    environment:
      - SPRING_PROFILES_ACTIVE=dev
      - SPRING_CLOUD_CONFIG_SERVER_GIT_URI=https://github.com/MuyleangIng/config-server.git
      - EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://eureka-server:8761/eureka/
    depends_on:
      - eureka-server
    networks:
      - spring-cloud-network

EOF
    fi

    if [[ ${services["api-gateway"]+1} ]]; then
        cat << EOF >> "$compose_file"
  api-gateway:
    build:
      context: ./api-gateway
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=dev
      - EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://eureka-server:8761/eureka/
    depends_on:
      - eureka-server
      - config-server
    networks:
      - spring-cloud-network

EOF
    fi

    if [[ ${services["user-service"]+1} ]]; then
        cat << EOF >> "$compose_file"
  user-service:
    build:
      context: ./user-service
      dockerfile: Dockerfile
    ports:
      - "8081:8081"
    environment:
      - SPRING_PROFILES_ACTIVE=dev
    depends_on:
      - eureka-server
      - config-server
    networks:
      - spring-cloud-network

EOF
    fi

    # Add Postgres service
    cat << EOF >> "$compose_file"
  postgres:
    image: postgres:14
    container_name: postgres-db
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: admin@123
      POSTGRES_DB: userdb
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - spring-cloud-network

volumes:
  postgres_data:

networks:
  spring-cloud-network:
    driver: bridge
EOF

    echo "Docker Compose file generated at $compose_file"
}

# Main loop to display the menu and handle user input
while true; do
    show_menu
    run_script "$option"
done

