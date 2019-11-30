# Copyright 2019 Hayo van Loon
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM golang:1.13-alpine AS builder

RUN apk --update --no-cache add git

ENV GO111MODULE=on

WORKDIR /build

COPY . .

RUN go get -d -v ./...
RUN CGO_ENABLED=0 GOOS=linux go build -o app

# Next stage
FROM alpine

RUN apk --update --no-cache add ca-certificates openssl

COPY --from=builder /build/app /usr/local/bin

CMD ["/usr/local/bin/app"]
