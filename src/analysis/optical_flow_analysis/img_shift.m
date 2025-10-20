function [original_img, shifted_img] = img_shift(img, u, v)

shifted_img  = imtranslate(img, [u,v]);
original_img = img;

end
