#!/bin/sh

ABSOLUTE_FILENAME=`readlink -e "$0"`
DIRECTORY=`dirname "${ABSOLUTE_FILENAME}"`
cd $DIRECTORY

echo "FM Radio DEB package generator"

while [ 1 ]; do
	echo -n "Enter version: "
	read v
	if [ -n "$v" ]
	then
		break
	fi
done

echo -n "Generate \"control\" file..."
rm -f package/DEBIAN/control
echo "Package: fmradio" >> package/DEBIAN/control
echo "Version: ${v}" >> package/DEBIAN/control
echo "Architecture: i386" >> package/DEBIAN/control
echo "Maintainer: Sergey Avdeev <thesoultaker48@gmail.com>" >> package/DEBIAN/control
s=`du -s package/usr/ | awk '{print $1}'`
echo "Installed-Size: ${s}" >> package/DEBIAN/control
echo "Depends: fmtools (>= 2.0.7)" >> package/DEBIAN/control
echo "Section: sound" >> package/DEBIAN/control
echo "Priority: optional" >> package/DEBIAN/control
echo "Homepage: http://tst48.wordpress.com" >> package/DEBIAN/control
echo "Description: FM-Radio Tuner" >> package/DEBIAN/control
echo " Minimalistic graphical user interface (GUI) for fmtools." >> package/DEBIAN/control
echo "OK!"

echo -n "Generate \"md5sums\" file..."
md5deep -r package/usr > package/DEBIAN/md5sums
echo "OK!"

fakeroot dpkg-deb -b package "fmradio_${v}_i386.deb"
