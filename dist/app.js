'use strict';
const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];
const plans = {base:{name:'Основа',rate:1900},full:{name:'Полный проект',rate:3200},care:{name:'С сопровождением',rate:4900}};
const format = (value) => new Intl.NumberFormat('ru-RU').format(value);
const state = {area:86,plan:'full',property:'Квартира'};
const menu = $('.menu-toggle');
menu.addEventListener('click', () => {
  const opened = menu.getAttribute('aria-expanded') !== 'true';
  menu.setAttribute('aria-expanded', String(opened));
  menu.setAttribute('aria-label', opened ? 'Закрыть меню' : 'Открыть меню');
  $('#navigation').classList.toggle('is-open', opened);
});
$$('#navigation a').forEach(link => link.addEventListener('click', () => {
  menu.setAttribute('aria-expanded','false');
  menu.setAttribute('aria-label','Открыть меню');
  $('#navigation').classList.remove('is-open');
}));
document.addEventListener('keydown', event => {
  if(event.key === 'Escape' && menu.getAttribute('aria-expanded') === 'true') {
    menu.click(); menu.focus();
  }
});
function renderEstimate() {
  $('#area').value = state.area;
  $('#area-number').value = state.area;
  $('#result-area').textContent = state.area + ' м²';
  $('#result-property').textContent = state.property;
  $('#result-plan').textContent = plans[state.plan].name;
  $('#result-price').textContent = format(state.area * plans[state.plan].rate);
  $(`input[name="plan"][value="${state.plan}"]`).checked = true;
}
$('#area').addEventListener('input', event => {state.area = Number(event.target.value); renderEstimate();});
$('#area-number').addEventListener('input', event => {
  const value = Number(event.target.value);
  if(value >= 30 && value <= 250 && Number.isInteger(value)) {state.area = value; $('#area').value = value; $('#result-area').textContent = value+' м²'; $('#result-price').textContent = format(value * plans[state.plan].rate);}
});
$('#area-number').addEventListener('change', event => {
  state.area = Math.min(250, Math.max(30, Math.round(Number(event.target.value) || 30)));
  renderEstimate();
});
$('#property').addEventListener('change', event => {state.property = event.target.value;renderEstimate();});
$$('input[name="plan"]').forEach(radio => radio.addEventListener('change', event => {state.plan=event.target.value;renderEstimate();}));
$('#estimate-form').addEventListener('submit', event => event.preventDefault());
$$('[data-plan]').forEach(button => button.addEventListener('click', () => {
  state.plan = button.dataset.plan;renderEstimate();
  $('#estimate').scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});
}));
$$('[data-filter]').forEach(button => button.addEventListener('click', () => {
  const filter = button.dataset.filter;
  $$('[data-filter]').forEach(tab => {tab.classList.toggle('active',tab===button);tab.setAttribute('aria-pressed',String(tab===button));});
  $$('[data-category]').forEach(card => card.hidden = filter !== 'all' && card.dataset.category !== filter);
  $('.project-grid').classList.toggle('filtered', filter !== 'all');
}));
const projects = [
  {title:'Свет и тишина',type:'Квартира',area:86,description:'Концепция светлой квартиры, где дневной свет становится частью интерьера. Открытое жилое пространство, спокойная палитра и мягкие формы создают место для отдыха и общения.',tags:['Светлая палитра','Дуб','Мягкие формы']},
  {title:'Ближе к природе',type:'Загородный дом',area:164,description:'Идея загородного дома, в котором интерьер продолжает природное окружение. Натуральные фактуры, приглушённые оттенки и свободная планировка помогают замедлиться и почувствовать пространство.',tags:['Природные оттенки','Натуральные фактуры','Открытая планировка']},
  {title:'Тёплый минимализм',type:'Квартира',area:62,description:'Компактное пространство с тёплым характером. В основе концепции — продуманное хранение, спокойные поверхности и тактильные детали. Минимум визуального шума, максимум удобства каждый день.',tags:['Компактное пространство','Тактильность','Продуманное хранение']}
];
function openDialog(dialog) {dialog.showModal();document.body.classList.add('is-modal-open');}
$$('dialog').forEach(dialog => {
  dialog.querySelector('.dialog-close').addEventListener('click',()=>dialog.close());
  dialog.addEventListener('close',()=>document.body.classList.remove('is-modal-open'));
  dialog.addEventListener('click',event=>{
    const rect=dialog.getBoundingClientRect();
    if(event.target===dialog&&(event.clientX<rect.left||event.clientX>rect.right||event.clientY<rect.top||event.clientY>rect.bottom))dialog.close();
  });
});
let currentProject = 0;
$$('[data-project]').forEach(card => card.addEventListener('click',()=>{
  currentProject=Number(card.dataset.project);
  const project=projects[currentProject];
  $('#dialog-image').src=card.querySelector('img').src;
  $('#dialog-image').alt=card.querySelector('img').alt;
  $('#dialog-title').textContent=project.title;
  $('#dialog-meta').textContent=project.type+' · '+project.area+' м² · Концепт / 2026';
  $('#dialog-description').textContent=project.description;
  $('#dialog-tags').replaceChildren(...project.tags.map(tag=>{const el=document.createElement('span');el.textContent=tag;return el;}));
  openDialog($('#project-dialog'));
}));
$('#project-to-estimate').addEventListener('click',()=>{
  const project=projects[currentProject];
  state.area=project.area;state.property=project.type;
  $('#property').value=state.property;renderEstimate();
  $('#project-dialog').close();
  $('#estimate').scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});
});
$('#open-brief').addEventListener('click',()=>{
  $('#brief-summary').textContent=`${state.property} · ${state.area} м² · ${plans[state.plan].name} · ${format(state.area*plans[state.plan].rate)} ₽`;
  $('#brief-status').textContent='';openDialog($('#brief-dialog'));
});
$('#brief-form').addEventListener('submit',event=>{
  event.preventDefault();
  const name=$('#brief-name').value.trim();
  const wishes=$('#brief-wishes').value.trim();
  if(!name||!wishes){$('#brief-status').textContent='Укажите имя и несколько пожеланий к интерьеру.';return;}
  const text=['БРИФ НА ДИЗАЙН ИНТЕРЬЕРА','ТИШЕ — демонстрационный проект','',`Имя: ${name}`,`Пространство: ${state.property}`,`Площадь: ${state.area} м²`,`Пакет: ${plans[state.plan].name}`,`Тариф: ${format(plans[state.plan].rate)} ₽ / м²`,`Предварительная стоимость дизайна: ${format(state.area*plans[state.plan].rate)} ₽`,'','Пожелания:',wishes,'','Демонстрационные цены. Ремонт, материалы и мебель не включены.','Файл создан локально. Данные в студию не отправлялись.'].join('\n');
  const url=URL.createObjectURL(new Blob(['\uFEFF'+text],{type:'text/plain;charset=utf-8'}));
  const a=document.createElement('a');a.href=url;a.download='tishe-interior-brief.txt';document.body.appendChild(a);a.click();a.remove();
  setTimeout(()=>URL.revokeObjectURL(url),2000);
  $('#brief-status').textContent='Бриф готов. Сохраните скачанный файл — все выбранные параметры уже внутри.';
});
renderEstimate();
