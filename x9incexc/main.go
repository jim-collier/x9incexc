package main

import (
	"database/sql"
	"fmt"
	"log"

	_ "github.com/mattn/go-sqlite3" // The underscore means to import it only for its side-effects. https://stackoverflow.com/questions/21220077/what-does-an-underscore-in-front-of-an-import-statement-mean
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
