# parallelGdal2tiles
A modified/commented version of the multithread gdal2tiles from http://trac.osgeo.org/gdal/ticket/4379

I know almost nothing about python currently so surely my additional code will be terrible

Goals:
 - Restore the auto zoom level determination ability in the multithread version (done, thoough very badly)
 - Better comment the code to see how the current process works
 - Optimize the process
 - Improve the quality of output graphics
 - Create a client/server version to distribute work amongst machines
