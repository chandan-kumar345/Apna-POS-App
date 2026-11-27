const transport = require('../src/services/mobileCampaignTransport');
const legacy = require('../src/services/campaignService');
const storage = require('../src/utils/storageService');

const businessId = 'a'.repeat(24);
const account = { waba:'test-waba', phone:'test-sender', token:'fixture-token' };
const campaign = () => ({ businessId, template: { metaTemplateName:'apna_test', category:'MARKETING', body:'Hi {{name}}, use WEEKEND20.',
  actions:[{type:'URL',text:'Order now',value:'https://example.test/menu'},{type:'PHONE_NUMBER',text:'Call store',value:'+919876543210'},
    {type:'QUICK_REPLY',text:'Interested',value:''}] } });
const response = value => ({ok:true,json:async()=>value});
afterEach(()=>jest.restoreAllMocks());

test('submits the selected category, actual image, personalization and all buttons intact',async () => {
  const c = campaign();
  const domain = storage.publicDomain;
  try {
    storage.publicDomain = 'https://images.example.test';
    c.template.headerMediaUrl = storage.publicDomain + '/campaigns/' + businessId + '/123_abcdef12.jpg';
    jest.spyOn(legacy,'_getMetaHeaderHandle').mockResolvedValue('image-handle');
    const mock = jest.spyOn(global,'fetch').mockResolvedValueOnce(response({data:[]})).mockResolvedValueOnce(response({id:'m1',status:'PENDING'}));
    expect(await transport.approval(c,account)).toBe('PENDING');
    const submitted = JSON.parse(mock.mock.calls[1][1].body);
    expect(submitted).toMatchObject({category:'MARKETING',language:'en',components:[
      {type:'HEADER',example:{header_handle:['image-handle']}},
      {type:'BODY',text:'Hi {{1}}, use WEEKEND20.'},
      {type:'BUTTONS',buttons:[{type:'URL',url:'https://example.test/menu'},{type:'PHONE_NUMBER',phone_number:'+919876543210'},{type:'QUICK_REPLY',text:'Interested'}]},
    ]});
    expect(()=>transport.validateImage('b'.repeat(24),c.template.headerMediaUrl)).toThrow();
    expect(()=>transport.validateImage(businessId,'https://another.example.test/img.jpg')).toThrow();
  } finally { storage.publicDomain = domain; }
});

test('delivery accepts a real provider message ID and sends the approved action parameters',async () => {
  const mock = jest.spyOn(global,'fetch').mockResolvedValueOnce(response({messages:[{id:'received-id'}]})).mockResolvedValueOnce(response({}));
  const c = campaign(), person = {name:'Leena',phone:'919876543210'};
  expect(await transport.send(c,account,person)).toBe('received-id');
  const [url,init] = mock.mock.calls[0];
  expect(url).toContain('test-sender/messages');
  expect(JSON.parse(init.body)).toMatchObject({to:person.phone,type:'template',template:{name:'apna_test',components:[
    {type:'body',parameters:[{text:'Leena'}]}, {type:'button',index:'2',parameters:[{type:'payload',payload:'Interested'}]},
  ]}});
  await expect(transport.send(c,account,person)).rejects.toThrow(/message ID/);
});

test('approval is tied to selected language and category',async () => {
  const c = campaign();
  const mock = jest.spyOn(global,'fetch').mockResolvedValueOnce(response({data:[
    {name:'apna_test',language:'en_US',category:'MARKETING',status:'APPROVED'},
    {name:'apna_test',language:'en',category:'UTILITY',status:'APPROVED'},
  ]}));
  expect(await transport.approval(c,account,false)).toBe('REJECTED');
  expect(mock).toHaveBeenCalledTimes(1);
});

test('Auth submits the Meta verification template and cannot broadcast offer text', async () => {
  const c = campaign(); c.template.category = 'AUTHENTICATION';
  const mock = jest.spyOn(global,'fetch').mockResolvedValueOnce(response({data:[]}))
    .mockResolvedValueOnce(response({id:'otp-template',status:'PENDING'}));
  await transport.approval(c,account);
  expect(JSON.parse(mock.mock.calls[1][1].body)).toMatchObject({category:'AUTHENTICATION',
    components:[{type:'BODY',add_security_recommendation:false},{type:'BUTTONS',buttons:[{type:'OTP',otp_type:'COPY_CODE'}]}]});
  await expect(transport.send(c,account,{})).rejects.toThrow(/verification code/);
  expect(mock).toHaveBeenCalledTimes(2);
});
