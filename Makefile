Audacity-x86_64.AppImage: binary/Audacity-x86_64.AppImage
	cp "$<" "$@"

binary/Audacity-x86_64.AppImage:
	docker-compose up --build