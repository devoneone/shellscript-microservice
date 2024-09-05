#!/bin/bash

set -euo pipefail

# Function to display the menu and handle user input
show_menu() {
    echo "Create Spring Services"
    echo "1. Eureka Service"
    echo "2. API Gateway"
    echo "3. Config Server"
    echo "4. User Service"
    echo "5. Exit"
    read -p "Please select an option [1-5]: " option
}

# Function to run the selected service creation script
run_script() {
    case "$1" in
        1)
            echo "Running Eureka Service setup..."
            ./create-eureka-server.sh
            ;;
        2)
            echo "Running API Gateway setup..."
            ./create-api-gateway.sh
            ;;
        3)
            echo "Running Config Server setup..."
            ./create-config-server.sh
            ;;
        4)
            echo "Running User Service setup..."
            ./create-user-service.sh
            ;;
        5)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose a number between 1 and 5."
            ;;
    esac
}

# Main loop to display the menu and handle user input
while true; do
    show_menu
    run_script "$option"
done

