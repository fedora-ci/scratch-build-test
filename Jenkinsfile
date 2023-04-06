#!groovy

@Library('fedora-pipeline-library@e39c66874db516f9c33f052936d78b566b90be53') _

def msg
def nvr
def artifactId
def allBuilds


// testcase name: baseos-qe.koji-build.copr-build.validation
def pipelineMetadata = [
    pipelineName: 'scratch-build-test',
    pipelineDescription: 'Scratch-build components in Koji',
    testCategory: 'validation',
    testType: 'copr-build',
    maintainer: 'baseos-qe',
    docs: 'https://github.com/fedora-ci/scratch-build-test',
    contact: [
        irc: '#fedora-ci',
        email: 'ci@lists.fedoraproject.org'
    ],
]


pipeline {

    agent {
        label 'node-generic-centos8-2'
    }

    options {
        buildDiscarder(logRotator(daysToKeepStr: '21', artifactNumToKeepStr: '100'))
        skipDefaultCheckout()
    }

    triggers {
       ciBuildTrigger(
           noSquash: true,
           providerList: [
               rabbitMQSubscriber(
                   name: 'RabbitMQ-public',
                   overrides: [
                       topic: 'org.fedoraproject.prod.bodhi.update.status.testing.koji-build-group.build.complete',
                       queue: '8d8bb00d-03d6-48e1-936a-05d22c728345'
                   ],
                   checks: [
                       [field: '$.artifact.release', expectedValue: '^f3[4-9]{1}$'],
                       [field: '$.artifact.builds[0].component', expectedValue: '^(glibc)$']
                   ]
               )
           ]
       )
    }

    parameters {
        string(name: 'CI_MESSAGE', defaultValue: '{}', description: 'CI Message')
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    msg = readJSON text: params.CI_MESSAGE
                    if (!msg) {
                        abort('Bad input, nothing to do.')
                    }

                    def kojiBuild = msg['artifact']['builds'][0]
                    artifactId = "koji-build:${kojiBuild['task_id']}"
                    nvr = kojiBuild['nvr']

                    def allBuildsJson = msg['artifact']['builds']
                    allBuilds = ""
                    allBuildsJson.each { key ->
                        if(!allBuilds) {
                            allBuilds = "${key['nvr']}"
                        } else {
                            allBuilds = "${allBuilds},${key['nvr']}"
                        }
                    }
                }
            }
        }

        stage('Scratch-Build in Koji') {

            environment {
                KOJI_KEYTAB = credentials('fedora-keytab')
                KRB_PRINCIPAL = 'bpeck/jenkins-continuous-infra.apps.ci.centos.org@FEDORAPROJECT.ORG'
                DIST_GIT_URL = 'https://src.fedoraproject.org'
                COPR_CONFIG = credentials('c9030754-3794-4f90-988b-42478fc36d4b')
            }

            steps {
                checkout scm

                sendMessage(type: 'running', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
                script {
                    sh("./createrepo.sh ${allBuilds} ${msg['artifact']['release']}")
                }
                script {
                    sh("./mass-prebuild.sh ${allBuilds} ${msg['artifact']['release']}")
                }
            }
        }
    }
    post {
        success {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
        }
        failure {
            sendMessage(type: 'error', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
        }
        unstable {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
        }
        always {
            archiveArtifacts artifacts: 'REPO/', fingerprint: true
        }
    }
}
