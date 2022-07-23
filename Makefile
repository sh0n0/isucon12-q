export GO111MODULE=on
DB_HOST:=127.0.0.1
DB_PORT:=3306
DB_USER:=root
DB_PASS:=root
DB_NAME:=isuports

MYSQL_CMD:=mysql -h$(DB_HOST) -P$(DB_PORT) -u$(DB_USER) -p$(DB_PASS) $(DB_NAME)

NGX_LOG_FOR_ALP:=/tmp/access_for_alp.log
NGX_LOG_FOR_KATARIBE:=/tmp/access_for_kataribe.log
MYSQL_LOG:=/tmp/slow-query.log

.PHONY: restart
restart:
	sudo systemctl restart isuports.service

.PHONY: before-profile
before-profile: restart-infra slow-on

.PHONY: restart-infra
restart-infra:
	$(eval when := $(shell date "+%s"))
	mkdir -p ~/logs/$(when)
	@if [ -f $(NGX_LOG_FOR_ALP) ]; then \
		sudo mv -f $(NGX_LOG_FOR_ALP) ~/logs/$(when)/ ; \
	fi
	@if [ -f $(NGX_LOG_FOR_KATARIBE) ]; then \
		sudo mv -f $(NGX_LOG_FOR_KATARIBE) ~/logs/$(when)/ ; \
	fi
	@if [ -f $(MYSQL_LOG) ]; then \
		sudo mv -f $(MYSQL_LOG) ~/logs/$(when)/ ; \
	fi
	sudo systemctl restart nginx
	sudo systemctl restart mysql

.PHONY: slow
slow: 
	sudo pt-query-digest $(MYSQL_LOG)

.PHONY: alp
alp:
	sudo cat $(NGX_LOG_FOR_ALP) | alp ltsv -r --sort=sum -m "\
	/api/player/player/[0-9a-zA-Z]+, \
	/api/organizer/competition/[0-9]+/ranking, \
	/api/organizer/competition/[0-9a-zA-Z]+/finish, \
	/api/organizer/player/[0-9a-zA-Z]+/disqualified", \
	/api/organizer/competition/[0-9a-zA-Z]+/score, \
	/api/player/competition/[0-9a-zA-Z]+/ranking
	"

.PHONY: kataribe
kataribe:
	sudo cat $(NGX_LOG_FOR_KATARIBE) | kataribe -f ./kataribe.toml


.PHONY: slow-on
slow-on:
	sudo $(MYSQL_CMD) -e "set global slow_query_log_file = '$(MYSQL_LOG)'; set global long_query_time = 0; set global slow_query_log = ON;"

.PHONY: slow-off
slow-off:
	sudo $(MYSQL_CMD) -e "set global slow_query_log = OFF;"
	
.PHONY: connect-db
connect-db:
	sudo $(MYSQL_CMD)

.PHONY: setup
setup:
	sudo apt install -y percona-toolkit unzip
	wget https://github.com/tkuchiki/alp/releases/download/v1.0.10/alp_linux_amd64.zip -O alp.zip
	unzip -o alp.zip
	sudo mv alp /usr/local/bin/
	sudo chmod +x /usr/local/bin/alp
	rm alp.zip
	wget https://github.com/matsuu/kataribe/releases/download/v0.4.3/kataribe-v0.4.3_linux_amd64.zip -O kataribe.zip
	unzip -o kataribe.zip
	sudo mv kataribe /usr/local/bin/
	sudo chmod +x /usr/local/bin/kataribe
	rm kataribe.zip
	kataribe -generate