
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {
default = "us-east-2"
}
variable "region" {
  type = string
  default = "us-east-2"
}

variable "vpcCidrBlock" {
  type = string
  default = "10.0.0.0/16"
}

variable "private_subnet" {
  type = list
  default = ["10.0.19.0/24", "10.0.20.0/24"]
}
variable "public_subnet" {
  type = list
  default = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "ami" {
    type    = string
    default = "ami-03a5def6b0190cef7"
}

variable "key_pair_name" {
    type    = string
    default = "valeo"
}
variable "azs" {
    type    = list
    default = ["us-east-2a" ,"us-east-2b"]
}
variable "db_password" {
  type    = string
  default = "magento"
}

variable "public_key" {
  description = "SSH public key"
  type        = string
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDXkrXvB6eYbWqwoAWM3YJa5vLhW+83A1c4vinSbVVdxUsLTFgceKY9Ur7q0EIkFYetFkoLz5hnUgaPFOSuYEnVuHL9L7hT7y5RHL+pJBwBLcmkymmGTCI1+2lbBGru09+IvyW7HSNOxkojVTmcsN9v294CSuwHKj7QJ2FRuCo9G6lwfHhCJHLPr2E7X9wJcHCKwlpUoLdIHO6+5OQbEiyPBp4A46NeLWq/1cMJiv9catMb4EBO8LcOhpqGzsqcthEKSZj/R28JrPWHfsBV3dQ2PUgHPts0OP+ilJZSwGWZV8GYl+25TfuveiVI7Zqhj00dUycvLeRGiiYssK4zuVhjv0DALMOjcybp326F8zIvruYU/DPernBWSi10nA+foUFMruAZ5TcCUt1dIVzywbqJKBgHaYOTg87FnCwsY9gLbZB0ZcQzPrsfhaviEfPKF01Gba69t2XD4J+FgmZu0JE1IfPktaCIZtfaU/IipUNvrmS0KpkW93mmQ/r6JCSNKcKEhwbkjJBOXURtfgoKV3PGHCp+B7RHSjysAAOP4vSnnuaGa/pHAeq/fBBzQeD62whgvVwDUGHL/rBXHeQeF49PryZ06nV/LDFFmudac5dzIDK19zZ+o4mwAF7E8wxilb2WenmRwKwD0DqkEEhp6j1+J7rfUsqzo2DS/j/GDDf6aQ=="
}
