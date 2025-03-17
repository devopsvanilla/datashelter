# create-awss4-cfn.md

```mermaid
        flowchart TB;
                subgraph;
                rootBucketPolicy[BucketPolicy<br/>S3::BucketPolicy]-->rootSecureS3Bucket[SecureS3Bucket<br/>S3::Bucket]
                rootBucketPolicy[BucketPolicy<br/>S3::BucketPolicy]-->roots3secures3bucket[s3secures3bucket<br/>External resource (aws::s3::secures3bucket)]
                rootDataShelterUser[DataShelterUser<br/>IAM::User]-->rootiamawspolicyiamuserchangepassword[iamawspolicyiamuserchangepassword<br/>External resource (aws::iam::policy)]
                rootDataShelterUserPolicy[DataShelterUserPolicy<br/>IAM::ManagedPolicy]-->roots3secures3bucket[s3secures3bucket<br/>External resource (aws::s3::secures3bucket)]
                rootDataShelterUserPolicy[DataShelterUserPolicy<br/>IAM::ManagedPolicy]-->rootDataShelterUser[DataShelterUser<br/>IAM::User]
                rootUserAccessKey[UserAccessKey<br/>IAM::AccessKey]-->rootDataShelterUser[DataShelterUser<br/>IAM::User]

        end
```
