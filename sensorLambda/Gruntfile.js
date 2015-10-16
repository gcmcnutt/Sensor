var grunt = require('grunt');
grunt.loadNpmTasks('grunt-aws-lambda');

grunt.initConfig({
    lambda_invoke: {
        default: {
        }
    },
    lambda_deploy: {
        default: {
            arn: 'arn:aws:lambda:us-east-1:499918285206:function:sensorKinesisHandler'
        }
    },
    lambda_package: {
        default: {
        }
    }
});

grunt.registerTask('deploy', ['lambda_package', 'lambda_deploy']);