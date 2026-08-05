resource "aws_subnet" "public" {

  count = length(var.public_subnet_cidrs)

  vpc_id = aws_vpc.this.id

  cidr_block = var.public_subnet_cidrs[count.index]

  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name}-public-${count.index + 1}"

      "kubernetes.io/role/elb" = "1"
    }
  )

}


resource "aws_subnet" "private" {

  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.this.id

  cidr_block = var.private_subnet_cidrs[count.index]

  availability_zone = var.availability_zones[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name}-private-${count.index + 1}"

      "kubernetes.io/role/internal-elb" = "1"
    }
  )

}