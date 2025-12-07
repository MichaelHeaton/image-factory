pipeline {
    agent {
        label 'proxmox-builder'  // Self-hosted Jenkins agent on private network
    }

    triggers {
        cron('0 2 1 * *')  // Run on 1st of every month at 2 AM
    }

    environment {
        PROXMOX_URL = credentials('proxmox-url')
        PROXMOX_API_TOKEN_ID = credentials('proxmox-token-id')
        PROXMOX_API_TOKEN_SECRET = credentials('proxmox-token-secret')
        PROXMOX_NODE = 'GPU01'
        PROXMOX_STORAGE_POOL = 'vmdks'
        PROXMOX_NETWORK_BRIDGE = 'vmbr0'
        VM_ID = '900'
        TEMPLATE_PATTERN = 'ubuntu-24.04-hardened-'
        KEEP_COUNT = '1'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Setup') {
            steps {
                sh '''
                    if ! command -v packer &> /dev/null; then
                        echo "Packer not found. Please install Packer on the Jenkins agent."
                        exit 1
                    fi
                    packer version
                '''
            }
        }

        stage('Initialize Packer') {
            steps {
                dir('packer/ubuntu-24.04') {
                    sh 'packer init ubuntu-24.04.pkr.hcl'
                }
            }
        }

        stage('Build Template') {
            steps {
                dir('packer/ubuntu-24.04') {
                    sh '''
                        packer build \
                            -var "proxmox_url=${PROXMOX_URL}" \
                            -var "proxmox_api_token_id=${PROXMOX_API_TOKEN_ID}" \
                            -var "proxmox_api_token_secret=${PROXMOX_API_TOKEN_SECRET}" \
                            -var "proxmox_node=${PROXMOX_NODE}" \
                            -var "proxmox_storage_pool=${PROXMOX_STORAGE_POOL}" \
                            -var "proxmox_network_bridge=${PROXMOX_NETWORK_BRIDGE}" \
                            -var "vm_id=${VM_ID}" \
                            ubuntu-24.04.pkr.hcl
                    '''
                }
            }
        }

        stage('Cleanup Old Templates') {
            when {
                expression { currentBuild.result == 'SUCCESS' }
            }
            steps {
                sh '''
                    export PROXMOX_URL="${PROXMOX_URL}"
                    export TOKEN_ID="${PROXMOX_API_TOKEN_ID}"
                    export TOKEN_SECRET="${PROXMOX_API_TOKEN_SECRET}"
                    export NODE="${PROXMOX_NODE}"
                    export TEMPLATE_PATTERN="${TEMPLATE_PATTERN}"
                    export KEEP_COUNT="${KEEP_COUNT}"
                    export DRY_RUN="false"

                    ./scripts/cleanup-old-templates.sh
                '''
            }
        }
    }

    post {
        success {
            echo 'Template build and cleanup completed successfully'
        }
        failure {
            echo 'Template build failed. Old templates were NOT deleted.'
        }
        always {
            cleanWs()
        }
    }
}

