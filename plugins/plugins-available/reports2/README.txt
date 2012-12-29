Reporting
=========

PDF Templates have to be in version 1.4
Use this command to convert:

gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen \
-dNOPAUSE -dQUIET -dBATCH \
-sOutputFile=my_templates/pdf/sla.pdf \
new_sla.pdf
