#version 120
/* DRAWBUFFERS:0 */
uniform sampler2D texture;
varying vec2 vTexCoord; varying vec4 vColor;
void main(){vec4 c=texture2D(texture,vTexCoord)*vColor;if(c.a<0.05)discard;gl_FragData[0]=vec4(c.rgb*1.2,c.a*0.7);}
