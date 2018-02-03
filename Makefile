
HEALTH_DATA_DIR=$(HOME)/HealthData
FIT_FILE_DIR=$(HEALTH_DATA_DIR)/FitFiles
FITBIT_FILE_DIR=$(HEALTH_DATA_DIR)/FitBitFiles
MSHEALTH_FILE_DIR=$(HEALTH_DATA_DIR)/MSHealth
DB_DIR=$(HEALTH_DATA_DIR)/DBs
BACKUP_DIR=$(HEALTH_DATA_DIR)/Backups

OLD_MONITORING_FIT_FILES_DIR=$(FIT_FILE_DIR)/2017_Monitoring
MONITORING_FIT_FILES_DIR=$(FIT_FILE_DIR)/2018_Monitoring
MEW_MONITORING_FIT_FILES_DIR=$(FIT_FILE_DIR)/Incoming

BIN_DIR=$(PWD)/bin

TEST_DB=$(TMPDIR)/test.db

OS := $(shell uname -s)
ARCH := $(shell uname -p)

all: import_new_monitoring scrape_new_weight garmin_summary

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(DB_DIR):
	mkdir -p $(DB_DIR)

$(BACKUP_DIR):
	mkdir -p $(BACKUP_DIR)

GECKO_DRIVER_URL=https://github.com/mozilla/geckodriver/releases/download/v0.19.1/
ifeq ($(OS), Darwin)
	GECKO_DRIVER_FILE=geckodriver-v0.19.1-macos.tar.gz
else ifeq ($(OS), Linux)
	ifeq ($(ARCH), x86_64)
		GECKO_DRIVER_FILE=geckodriver-v0.19.1-linux64.tar.gz
	else
		GECKO_DRIVER_FILE=geckodriver-v0.19.1-linux32.tar.gz
	endif
endif
install_geckodriver: $(BIN_DIR)
	curl -L $(GECKO_DRIVER_URL)/$(GECKO_DRIVER_FILE) | tar -C $(BIN_DIR) -x -z -f -

clean_geckodriver:
	rm -f $(BIN_DIR)/geckodriver*

deps: install_geckodriver
	sudo pip install sqlalchemy
	sudo pip install selenium

clean_deps:
	sudo pip uninstall sqlalchemy
	sudo pip uninstall selenium

clean:
	rm -rf *.pyc
	rm -rf Fit/*.pyc
	rm -rf HealthDB/*.pyc
	rm -rf GarminDB/*.pyc
	rm -rf FitBitDB/*.pyc

TEST_DB_PATH=/tmp/DBs
$(TEST_DB_PATH):
	mkdir -p $(TEST_DB_PATH)

EPOCH=$(shell date +'%s')
backup: $(BACKUP_DIR)
	zip -r $(BACKUP_DIR)/$(EPOCH)_dbs.zip $(DB_DIR)

clean_summary:
	rm -f $(DB_DIR)/summary.db


#
# Garmin
#
test_monitoring_clean:
	rm -rf $(TEST_DB_PATH)

TEST_FIT_FILE_DIR=$(HEALTH_DATA_DIR)/TestFitFiles
test_monitoring_file: $(TEST_DB_PATH)
#	python import_garmin_fit.py -e --input_file "$(TEST_FIT_FILE_DIR)/15044952621.fit" --dbpath $(TEST_DB_PATH)
	python import_garmin_fit.py -t -e --input_dir "$(TEST_FIT_FILE_DIR)" --sqlite $(TEST_DB_PATH) && \
	python analyze_garmin.py --sqlite $(TEST_DB_PATH) --years --months 2018 --days 2017

clean_monitoring:
	rm -f $(DB_DIR)/garmin_monitoring.db

scrape_monitoring: $(DB_DIR)
	python scrape_garmin.py -d $(GC_MON_DATE) -n $(GC_DAYS) -u $(GC_USER) -p $(GC_PASSWORD)  -m "$(MEW_MONITORING_FIT_FILES_DIR)"

import_monitoring: $(DB_DIR)
	python import_garmin_fit.py -e --input_dir "$(OLD_MONITORING_FIT_FILES_DIR)" --sqlite $(DB_DIR)
	python import_garmin_fit.py -e --input_dir "$(MONITORING_FIT_FILES_DIR)" --sqlite $(DB_DIR)

scrape_new_monitoring: $(DB_DIR)
	python scrape_garmin.py -l --sqlite $(DB_DIR) -u $(GC_USER) -p $(GC_PASSWORD)  -m "$(MEW_MONITORING_FIT_FILES_DIR)"

import_new_monitoring: scrape_new_monitoring
	if ls $(MEW_MONITORING_FIT_FILES_DIR)/*.fit 1> /dev/null 2>&1; then \
		python import_garmin_fit.py -e --input_dir "$(MEW_MONITORING_FIT_FILES_DIR)" --sqlite $(DB_DIR); \
		mv $(MEW_MONITORING_FIT_FILES_DIR)/*.fit $(MONITORING_FIT_FILES_DIR)/.; \
	fi

scrape_weight: $(DB_DIR)
	python scrape_garmin.py -d $(GC_DATE) -n $(GC_DAYS) -u $(GC_USER) -p $(GC_PASSWORD)  -w "$(DB_DIR)"

scrape_new_weight: $(DB_DIR)
	python scrape_garmin.py -l --sqlite $(DB_DIR) -u $(GC_USER) -p $(GC_PASSWORD)  -w "$(DB_DIR)"

clean_garmin_summary:
	rm -f $(DB_DIR)/garmin_summary.db

garmin_summary:
	python analyze_garmin.py --sqlite $(DB_DIR) --years --months 2017 --days 2017
	python analyze_garmin.py --sqlite $(DB_DIR) --years --months 2018 --days 2018

new_garmin: import_new_monitoring clean_garmin_summary garmin_summary

clean_garmin: clean_garmin_summary clean_monitoring


#
# FitBit
#
import_fitbit_file: $(DB_DIR)
	python import_fitbit_csv.py -e --input_file "$(FITBIT_FILE_DIR)/2015_fitbit_all.csv" --sqlite $(DB_DIR)

clean_fitbit:
	rm -f $(DB_DIR)/fitbit.db

fitbit_summary:
	python analyze_fitbit.py --sqlite $(DB_DIR) --years --months 2015 --days 2015


#
# MS Health
#
import_mshealth_file: $(DB_DIR)
	python import_mshealth_csv.py -e --input_file "$(MSHEALTH_FILE_DIR)/Daily_Summary_20151230_20161004.csv" --sqlite $(DB_DIR) -m
	python import_mshealth_csv.py -e --input_file "$(MSHEALTH_FILE_DIR)/Daily_Summary_20160101_20161231.csv" --sqlite $(DB_DIR) -m
	python import_mshealth_csv.py -e --input_file "$(MSHEALTH_FILE_DIR)/Daily_Summary_20170101_20170226.csv" --sqlite $(DB_DIR) -m

import_healthvault_file: $(DB_DIR)
	python import_mshealth_csv.py -e --input_file "$(MSHEALTH_FILE_DIR)/HealthVault_Weight_20150106_20160315.csv" --sqlite $(DB_DIR) -v

clean_mshealth:
	rm -f $(DB_DIR)/mshealth.db

mshealth_summary:
	python analyze_mshealth.py --sqlite $(DB_DIR) --years --months 2015 --days 2015
	python analyze_mshealth.py --sqlite $(DB_DIR) --years --months 2016 --days 2016
