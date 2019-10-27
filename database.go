package main

import (
	"crypto/subtle"
	"database/sql"
	_ "github.com/go-sql-driver/mysql"
	"github.com/akkuman/parseConfig"
	"os"
	"regexp"
)

var db = &sql.DB{}
var config parseConfig.Config

func dbInit() {
	// create DB connection
	//dbUsername := os.Getenv("DB_USERNAME")
	//dbPassword := os.Getenv("DB_PASSWORD")
	//dbHost := os.Getenv("DB_HOST")
	//dbPort := os.Getenv("DB_PORT")
	//dbName := os.Getenv("DB_NAME")
	config = parseConfig.New("config.json")
	
	dbUsername := config.Get("Mysql_User").(string)
	dbPassword := config.Get("Mysql_Password").(string)
	dbHost := config.Get("Mysql_Host").(string)
	dbPort := config.Get("Mysql_Port")
	dbName := config.Get("Mysql_Db").(string)
	
	dbString := dbUsername + ":" +
		dbPassword + "@tcp(" +
		dbHost + ":" +
		dbPort + ")/" +
		dbName
	var err error
	db, err = sql.Open("mysql", dbString)
	if err != nil {
		panic(err)
	}
}

func authenticate(device string, token string) bool {
	matchedDevice, _ := regexp.MatchString("^[a-zA-Z0-9]*$", device)
	matchedToken, _ := regexp.MatchString("^[a-zA-Z0-9]*$", token)
	if !matchedDevice || !matchedToken {
		return false
	}
	var col string
	sqlStatement := `SELECT token FROM devices WHERE enable=1 AND device=?;`
	scanErr := db.QueryRow(sqlStatement, device).Scan(&col)
	if scanErr != nil {
		if scanErr != sql.ErrNoRows {
			panic(scanErr)
		}
		return false
	}
	if subtle.ConstantTimeCompare([]byte(col), []byte(token)) == 1 {
		return true
	}
	return false
}
