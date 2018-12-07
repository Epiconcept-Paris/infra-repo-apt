top:; @date

#roles:; ansible-galaxy install -i -r requirements.yml
#.PHONY: roles

once:; mkdir -p .cache .retry roles log 
clean:; rm -rf .cache .retry roles log
