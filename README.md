# FFchapters - FFmpeg based chapter creation

## About
Movies for e.g. created from TV recordings do not have any chapters. These chapters can be generated by using FFMpeg and FFchapters.
FFmpeg is capable of finding scene changes via video filter. The problem is that FFmpeg does not create a regular chapter file out of this information.
Therefore these scene changes can be extracted by FFchapters which will create a standard chapter file usable for e.g. with Matroska.

## Workflow
The workflow is:
* generate with FFMpeg a raw log file which contains the the scene changes
* generate with FFchapters a regular chapter file out of this raw log file

## Example

### FFmpeg scene detection of a movie file using video filters: Scene, Black and Blackframe detection
FFmpeg -i "Video_File" -vf blackdetect=d=1.0:pic_th=0.90:pix_th=0.00,blackframe=98:32,"select='gt(scene,0.75)',showinfo" -an -f null - 2> "FFmpeg_Log_File"

### FFchapters chapter generation out of above created FFmpeg log file with around 5 minutes (300 seconds) duration between each chapter 
FFchapters -i "FFmpeg_Log_File" -o "Chapter_Output_File" -s 300

## Result
The created "Chapter_Output_File" can now be used with video (muxer) tools for e.g. with MKVToolNix GUI as chapter input file.