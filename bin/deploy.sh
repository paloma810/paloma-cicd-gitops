# 共通関数
function ConfirmExecution() {
  execution=$1
  echo "----------------------------"
  echo "${execution}を実行しますか?"
  echo "  実行する場合は yes、実行をキャンセルする場合は no と入力して下さい."
  read input

  if [ -z $input ] ; then
    echo "  yes または no を入力して下さい."
    ConfirmExecution
  elif [ $input = 'yes' ] || [ $input = 'YES' ] || [ $input = 'y' ] ; then
    echo "  ${execution}を実行します."
  elif [ $input = 'no' ] || [ $input = 'NO' ] || [ $input = 'n' ] ; then
    echo "  ${execution}の実行をキャンセルします."
    exit 1
  else
    echo "  yes または no を入力して下さい."
    ConfirmExecution
  fi
}

# 環境変数
export TF_VAR_aws_access_key="AKIAXXXXXXXXXXXXXXXXXX"
export TF_VAR_aws_secret_key="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
export ENV="dev"
export CLOUD="gc"
export COMPONENTS="common"
export WORK_DIR="/Users/machida/work/projects/docker/terraform/src/cicd/paloma-cicd-gitops/components/${CLOUD}/${COMPONENTS}"

# main処理
echo $TF_VAR_aws_access_key
echo $TF_VAR_aws_secret_key
echo $ENV
echo $CLOUD
echo $COMPONENTS
echo $WORK_DIR
cd $WORK_DIR
# workspaceは利用しない
# terraform workspace select [ default / product / staging / develop ]
# 初期化　このタイミングでbackendのprefixを環境に対応するもので更新する
terraform init --backend-config=prefix=${ENV}/${CLOUD}/${COMPONENTS} -migrate-state

# Dry run
#terraform plan \
terraform plan \
-var-file="../../../environments/terraform.tfvars" \
-var-file="../../../environments/${ENV}/terraform.tfvars" \
-var-file="../../../environments/${ENV}/${CLOUD}/terraform.tfvars" \
-var-file="../../../environments/${ENV}/${CLOUD}/${COMPONENTS}/terraform.tfvars" \
| grep --line-buffered -E '^\S+|y^\s{,2}(\+|-|~|-/\+) |^\s<=|^Plan'

ConfirmExecution "terraform apply"

terraform apply \
-var-file="../../../environments/terraform.tfvars" \
-var-file="../../../environments/${ENV}/terraform.tfvars" \
-var-file="../../../environments/${ENV}/${CLOUD}/terraform.tfvars" \
-var-file="../../../environments/${ENV}/${CLOUD}/${COMPONENTS}/terraform.tfvars"