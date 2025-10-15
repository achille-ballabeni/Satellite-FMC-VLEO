% Buongiorno,
% dando seguito alla discussione di ieri pomeriggio, lascio il link a due
% funzioni di Matlab per inserire il motion-blur nelle immagini usate per
% calcolare il LoS motion:
%
% https://www.mathworks.com/help/images/ref/fspecial.html
%
% https://it.mathworks.com/help/images/ref/imfilter.html
%
% La prima dovrebbe creare la matrice di convoluzione, la seconda serve ad
% applicare il filtro alla data immagine. Il motion blur viene specificato
% tramite numero di pixel e direzione rispetto all'orizzontale. Credo
% quindi sia abbastanza immediato implementarlo utilizzando le informazioni
% già disponibili nel vostro modello per il calcolo dello shift tra la
% coppia di immagini. Di primo acchito, credo che l'intensità del motion
% blur si ottenga semplicemente scalando lo shift tra le due immagini per
% il rapporto (assumed_exposure_time/frame rate), come ci dicevamo l'altro
% giorno.
%
% Oltre a questo, sarebbe a mio avviso interessante fare un breve studio su
% come l'algoritmo di optical flow scali (in termini di
% latency_vs_accuracy) al diminuire della dimensione dell'immagine
% utilizzata. Quest'ultima la testerei ipotizzando di fare un cropping
% centrato nel centro dell'immagine, ovvero tagliando "i bordi"  passando
% ad es da 1920x1080 a 960x540 –> 480x270.
%
% Spero quanto sopra sia d'aiuto.

u = 100;
v = 1.9;
exposure_time = 1/500;
dt = 0.1;

image = imread("D:\AKO\UNI_AERO\Tesi_Magistrale\VLEO_numerical_simulator\src\media\full_img.png");

blur_len = sqrt(u^2+v^2)*exposure_time/dt;
blur_angle = rad2deg(atan(v/u));
H = fspecial("motion",blur_len,blur_angle);
blurred_img = imfilter(image,H,"replicate");

targetSize = [480,270];
r = centerCropWindow2d(size(blurred_img),targetSize);
cropped = imcrop(blurred_img,r);

[original_img, shifted_img] = img_shift(cropped,u,v);
tic
[u_est,v_est] = OF(original_img,shifted_img,10)
toc