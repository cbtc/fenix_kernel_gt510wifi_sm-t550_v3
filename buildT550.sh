#!/bin/bash
#Cleanup before build
	rm -rf $(pwd)/output
	rm -rf $(pwd)/hK-out
	make clean

#The build 
	export ARCH=arm
	export CROSS_COMPILE=$(pwd)/hK-tools/arm-eabi-4.8/bin/arm-eabi-
	mkdir -p output hK-out/pack/rd hK-out/zip/hades hK-zip

	make -C $(pwd) O=output msm8916_sec_defconfig VARIANT_DEFCONFIG=t550_defconfig SELINUX_DEFCONFIG=selinux_defconfig
	make -j64 -C $(pwd) O=output

# zImage copying - assuming the zimage is built
	cp output/arch/arm/boot/zImage $(pwd)/hK-out/pack/zImage

# DTS packing
	./tools/dtbTool -v -s 2048 -o ./hK-out/pack/dts ./output/arch/arm/boot/dts/

#Ramdisk packing
	echo "Building ramdisk structure..."
	cp -r hK-tools/ramdisk/common/* hK-out/pack/rd
	cp -r hK-tools/ramdisk/T550/* hK-out/pack/rd
	cd $(pwd)/hK-out/pack/rd
	mkdir -p data dev oem proc sys system
	echo "Setting ramdisk file permissions..."
	# set all directories to 0755 by default
	find -type d -exec chmod 755 {} \;
	# set all files to 0644 by default
	find -type f -exec chmod 644 {} \;
	# scripts should be 0750
	find -name "*.rc" -exec chmod 750 {} \;
	find -name "*.sh" -exec chmod 750 {} \;
	# init and everything in /sbin should be 0750
	chmod -Rf 750 init sbin
	chmod 771 data
	find | fakeroot cpio -o -H newc | gzip -9 > ../hK-ramdisk.gz
	cd ../../../

echo "Generating boot.img..."
echo ""
./hK-tools/mkbootimg --kernel ./hK-out/pack/zImage \
				--ramdisk ./hK-out/pack/hK-ramdisk.gz \
				--cmdline "console=null androidboot.hardware=qcom user_debug=23 msm_rtb.filter=0x3F ehci-hcd.park=3 androidboot.bootdevice=7824900.sdhci" \
				--base 80000000 \
				--pagesize 2048 \
				--kernel_offset 00008000 \
				--ramdisk_offset 02000000 \
				--tags_offset 01e00000 \
				--dt ./hK-out/pack/dts \
				--output $(pwd)/hK-out/zip/boot.img

echo -n "SEANDROIDENFORCE" >> $(pwd)/hK-out/zip/boot.img

#Auto made zips for F only - now
cp -r $(pwd)/hK-tools/META-INF $(pwd)/hK-out/zip/
sed -i 's/A500xx/A500F/g' $(pwd)/hK-out/zip/META-INF/com/google/android/aroma-config
cp -r $(pwd)/output/drivers/staging/prima/wlan.ko $(pwd)/hK-out/zip/hades/hades
cp -r $(pwd)/output/drivers/media/radio/radio-iris-transport.ko $(pwd)/hK-out/zip/hades/radio
cp -r $(pwd)/hK-tools/scripts/* $(pwd)/hK-out/zip/hades/
cp -r $(pwd)/hK-tools/*SuperSU*.zip $(pwd)/hK-out/zip/hades/SuperSU.zip
cd hK-out/zip
zip -r -9 - * > ../../hK-zip/"A500F$(cat ../../.scmversion).zip"
cd ../../

echo "Done!"



