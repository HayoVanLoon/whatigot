/*
 * Copyright 2019 Hayo van Loon
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */
package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
)

func handle(w http.ResponseWriter, r *http.Request) {
	b := strings.Builder{}

	b.WriteString("=== General ===\n")
	b.WriteString(fmt.Sprintf("%s %s", r.Method, r.URL))

	b.WriteString("\n\n=== Headers ===\n")
	printHeaders(&b, r)

	printAuth(&b, r)

	b.WriteString("\n=== Cookies ===\n")
	printCookies(&b, r)
	b.WriteString("\n")

	b.WriteString("\n----- Body -----\n")
	printBody(&b, r)
	b.WriteString("\n----------------\n")

	w.Header().Add("Content-Type", "text/plain")
	_, err := w.Write([]byte(b.String()))
	if err != nil {
		log.Print(err.Error())
	}
}

func printHeaders(b *strings.Builder, r *http.Request) {
	for k, vs := range r.Header {
		for _, v := range vs {
			b.WriteString(fmt.Sprintf("%s: %s\n", k, v))
		}
	}
}

func printAuth(b *strings.Builder, r *http.Request) {
	if auth := r.Header.Get("Authorization"); auth != "" {
		if strings.ToLower(auth[0:7]) == "bearer " {
			b.WriteString("\n=== JWT Token ===\n")
			printJwt(b, auth)
		} else if strings.ToLower(auth[0:6]) == "basic " {
			b.WriteString("\n=== Basic Auth ===\n")
			printBasicAuth(b, auth)
		}
	}
}

func printJwt(b *strings.Builder, auth string) {
	ss := strings.Split(auth[7:], ".")
	s, err := base64.RawURLEncoding.DecodeString(ss[1])
	if err == nil {
		var i interface{}
		err = json.Unmarshal(s, &i)
		if err == nil {
			for k, v := range i.(map[string]interface{}) {
				b.WriteString(fmt.Sprintf("%s: %v\n", k, v))
			}
		}
	}
}

func printBasicAuth(b *strings.Builder, auth string) {
	s, err := base64.RawURLEncoding.DecodeString(auth[6:])
	if err == nil {
		ss := strings.Split(string(s), ":")
		b.WriteString(ss[0] + ":<redacted for viewing pleasure>")
		b.WriteString("Do not store this output! Password is out in the open!")
	}
}

func printCookies(b *strings.Builder, r *http.Request) {
	for _, c := range r.Cookies() {
		age := ""
		if c.MaxAge > 0 {
			age = fmt.Sprintf(" [%v]", c.MaxAge)
		}
		ho := ""
		if c.HttpOnly {
			ho = " http-only"
		}
		sec := ""
		if c.Secure {
			sec = " secure"
		}
		b.WriteString(fmt.Sprintf("%s/%s%s%s%s: %s", c.Domain, c.Path, age, ho, sec, c.Value))
	}
}

func printBody(b *strings.Builder, r *http.Request) {
	rc := r.Body
	p := make([]byte, 1024)
	for l, err := rc.Read(p); l > 0; l, err = rc.Read(p) {
		b.Write(p[0:l])
		if err != nil {
			break
		}
	}
}

func main() {
	http.HandleFunc("/", handle)

	log.Fatal(http.ListenAndServe(":8080", nil))
}
