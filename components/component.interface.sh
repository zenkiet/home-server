#!/bin/bash

component_name () {
    echo "Component Name"
}

component_description () {
    echo "Component Description"
}

component_dependencies() {
    echo "dep1 dep2"
}

component_validate () {
    return 0
}

component_install() {
    return 0
}

component_configure() {
    return 0
}

component_uninstall() {
    return 0
}

component_status() {
    echo "installed|not-installed|partial"
}

component_version() {
    echo "1.0.0"
}

component_author() {
    echo "ZenKiet"
}