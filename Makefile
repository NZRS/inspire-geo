test:
	for perl in lib/Inspire/Geo.pm bin/*; do perl -I lib -c $$perl && perlcritic --brutal $$perl; done
clean:
	rm -f var/example-output/north-island-coverage.*

