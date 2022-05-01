package main

import (
	"database/sql"
	"fmt"
	"log"

	_ "github.com/mattn/go-sqlite3"
)

//import "github.com/alexflint/go-arg"

// Version is for x9go_build
var Version string

// GitCommitHash is for x9go_build
var GitCommitHash string

// BuildDateTime is for x9go_build
var BuildDateTime string

func main() {
	fmt.Println("Version ...........: ", Version)
	fmt.Println("Git commit hash ...: ", GitCommitHash)
	fmt.Println("Build date/time ...: ", BuildDateTime)

	db, err := sql.Open("sqlite3", "")
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()
}
