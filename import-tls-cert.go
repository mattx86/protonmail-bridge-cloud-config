/*
Copyright (c) 2023 Matt Smith
MIT License

Purpose:
To import an SSL certificate into the ProtonMail Bridge
via the interactive CLI.  (Is there a better way?)
*/

package main

import (
	"log"
	"regexp"
	"time"
	"os"

	"github.com/google/goexpect"
)

const (
	timeout = 1 * time.Minute
)

var (
	promptRE = regexp.MustCompile(">>>")
	cert_pem_RE = regexp.MustCompile("Enter the path to the cert.pem file")
	key_pem_RE  = regexp.MustCompile("Enter the path to the key.pem file")
)

func main() {
	e, _, err := expect.Spawn("/usr/local/bin/proton-bridge-cli", -1)
	if err != nil {
		log.Fatal(err)
	}
	defer e.Close()

	e.Expect(promptRE, timeout)
	e.Send("import-tls-cert\n")
	e.Expect(cert_pem_RE, timeout)
	e.Send(os.Args[1] + "\n")
	e.Expect(key_pem_RE, timeout)
	e.Send(os.Args[2] + "\n")

	e.Expect(promptRE, timeout)
	e.Send("exit\n")
}

