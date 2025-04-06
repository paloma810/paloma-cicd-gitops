####################################
## terraform deploy スクリプト
##  - 引数
##　　 1. ENV ... 対象の環境
##    2. CLOUD ... 対象のクラウド
##    3. COMPONENTS ... 対象のコンポーネント
##
####################################

# 共通関数
Logger() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  case "$level" in
    "DEBUG")
      echo "$timestamp [DEBUG] $message"
      ;;
    "INFO")
      echo "$timestamp [INFO] $message"
      ;;
    "WARNING")
      echo "$timestamp [WARNING] $message"
      ;;
    "ERROR")
      echo "$timestamp [ERROR] $message"
      ;;
    *)
      echo "$timestamp [UNKNOWN] $message"
      ;;
  esac
}

function ConfirmExecution() {
  local execution=$1
  echo "----------------------------"
  echo "${execution}を実行しますか?"
  echo "Enter yes or no"
  read input

  if [ -z $input ] ; then
    echo " Enter yes or no"
    ConfirmExecution
  elif [ $input = 'yes' ] || [ $input = 'YES' ] || [ $input = 'y' ] ; then
    Logger "INFO" "${execution}を実行します."
  elif [ $input = 'no' ] || [ $input = 'NO' ] || [ $input = 'n' ] ; then
    Logger "INFO" "${execution}の実行をキャンセルします."
    exit 1
  else
    echo "Enter yes or no"
    ConfirmExecution
  fi
}

function CheckState() {
  if [ $? -ne 0 ]; then
    Logger "ERROR" "Failed execution"
    exit 0
  fi
}

# main処理
# 引数チェック
EXPECTED_ARGS=3
if [ "$#" -ne "${EXPECTED_ARGS}" ]; then
  Logger "ERROR" "引数の数が正しくありません。"
  Logger "ERROR" "期待される引数の数: ${EXPECTED_ARGS} (ENV CLOUD COMPONENTS)"
  Logger "ERROR" "指定された引数の数: ${#}"
  exit 1 # エラー終了
fi

# 環境変数
export TF_VAR_aws_access_key="AKIAXXXXXXXXXXXXXXXXXX"
export TF_VAR_aws_secret_key="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
export ENV=${1}
export CLOUD=${2}
export COMPONENTS=${3}
Logger "INFO" "ENV: ${CLOUD}, CLOUD: ${CLOUD}, $COMPONENTS: ${COMPONENTS}"
export WORK_DIR="/Users/machida/work/projects/docker/terraform/src/cicd/paloma-cicd-gitops/components/${CLOUD}/${COMPONENTS}"

cd $WORK_DIR
# workspaceは利用しない
# terraform workspace select [ default / product / staging / develop ]
# 初期化　このタイミングでbackendのprefixを環境に対応するもので更新する
Logger "INFO" "*** terraform init ***"
terraform init --backend-config=prefix=${ENV}/${CLOUD}/${COMPONENTS} -migrate-state
CheckState

Logger "INFO" "*** terraform plan ***"
terraform plan \
-var-file="../../../environments/terraform.tfvars" \
-var-file="../../../environments/${ENV}/terraform.tfvars" \
-var-file="../../../environments/${ENV}/${CLOUD}/terraform.tfvars" \
-var-file="../../../environments/${ENV}/${CLOUD}/${COMPONENTS}/terraform.tfvars" #\
#| grep --line-buffered -E '^\S+|y^\s{,2}(\+|-|~|-/\+) |^\s<=|^Plan'
CheckState

ConfirmExecution "terraform apply"

Logger "INFO" "*** terraform apply ***"
terraform apply \
-var-file="../../../environments/terraform.tfvars" \
-var-file="../../../environments/${ENV}/terraform.tfvars" \
-var-file="../../../environments/${ENV}/${CLOUD}/terraform.tfvars" \
-var-file="../../../environments/${ENV}/${CLOUD}/${COMPONENTS}/terraform.tfvars"
CheckState