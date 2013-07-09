// = require jquery
// = require jquery_ujs
// = require jquery.qtip.min

// = require jquery-ui
// = require jquery.ui.datepicker-en-US
// = require jquery.ui.datepicker-pt-BR

// = require jquery.dropdown

// = require tooltip
// = require mysolar
// = require lightbox
// = require message
// = require lesson
// = require allocation

// = require intro.min

/*************************************************************************************
 * Atualiza o conteudo da tela por ajax.
 * Utilizado por funções genéricas de seleção como a paginação ou a seleção de turmas.
 * */
function reloadContentByForm(form){
  var rscript = /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi;

  var type = $(form).attr("method");
  var url = ''; // window.location;
  var selector = "#mysolar_content";
  var target = $("#mysolar_content");

  var params = '';
  var isFirst = true;
  $.each($(form).children(), function(index, value) {
    var name = $(value).attr("name");
    var val = $(value).attr("value");

    if (!isFirst)
      params += "&"
    params += name + "="+val;
    isFirst = false;
  });

  // Request the remote document
  jQuery.ajax({
    url: url,
    type: type,
    dataType: "html",
    data: params,//params,
    complete: function( jqXHR, status, responseText ) {
      responseText = jqXHR.responseText;
      target.html(jQuery("<div>").append(responseText.replace(rscript, "")).find(selector));
      showAgenda();
    }
  });
  return false;
}


/*******************************************************************************
 * Upload das imagens de usuário.
 * */
function showUserPictureUploadForm(url, title){
  showLightBoxURL(url, 500, 400, true, title);
  return false;
}

/*******************************************************************************
 * Código do Menu de usuário na barra superior
 * */
$(document).ready(function(){
  $("body").click(function(e) {
    if((e.target.id !== 'mysolar_top_submenu') && (e.target.id !== 'mysolar_top_user_nick') && (e.target.id !== 'image_user')){
      $("#mysolar_top_submenu").slideUp(150);
      $('#mysolar_top_submenu_label').removeClass('mysolar_top_submenu_label_selected');
      $('#mysolar_top_submenu_label').addClass('mysolar_top_submenu_label_regular');
    }      
  });
});

function mysolarTopSubmenuToggle(){
  var left = $("#mysolar_top_user_nick").offset().left;
  var origin = $("#mysolar_topbar").offset().left;
  left -= origin;
  $("#mysolar_top_submenu").css('left', left);
  $("#mysolar_top_submenu").slideToggle(150);
  $('#mysolar_top_submenu_label').toggleClass('mysolar_top_submenu_label_selected');
  $('#mysolar_top_submenu_label').toggleClass('mysolar_top_submenu_label_regular');
}

/*******************************************************************************
 * Código do Menu Accordion com estado salvo em cookies.
 * */
$(document).ready(function() {
  $('.mysolar_menu_title').click(function() {
    // verificando se o item do menu já está ativo
    if ( $(this).parent().hasClass('mysolar_menu_title_active') == false ) {
      // limpando o menu, removendo itens ativos e ocultando submenu
      $('.mysolar_menu_title').each(function(){
        $(this).parent().removeClass('mysolar_menu_title_active').removeClass('mysolar_menu_title_single_active');
        $(this).find('div').removeClass('menu_icon_animate');
        $(this).next('.submenu').slideUp('fast');
      });
    }
    // verificando se o item possui filhos
    if ( $(this).parent().hasClass('mysolar_menu_title_single') == false ) {
      // adicionando icone da seta
      $(this).parents('li').find('.menu_icon_arrow').addClass('menu_icon_animate');
      // tornando o item ativo
      $(this).parent().addClass('mysolar_menu_title_active');
      // exibindo submenu
      $(this).next('.submenu').slideDown('fast');
    } else {
      // adicionando icone da bolinhaaaaaa
      $(this).parents('li').find('.menu_icon_circle').addClass('.menu_icon_animate');
      // tornando o item ativo
      $(this).parent().addClass('mysolar_menu_title_single_active');
    }
  });

  if($('.mysolar_menu_title_single > a').children("div.menu_icon_circle").length == 0)
    $('.mysolar_menu_title_single > a').prepend('<div class="menu_icon_circle">&bull;</div>');
  
  if($('.mysolar_menu_title_multiple > a').children("div.menu_icon_arrow").length == 0)
    $('.mysolar_menu_title_multiple > a').prepend('<div class="menu_icon_arrow">&#8227;</div>');

  // abre menu corrente
  $('.open_menu').click();

  checkCookie();

  function setCookie(c_name,value,exdays) {
    var exdate=new Date();
    exdate.setDate(exdate.getDate() + exdays);
    var c_value=escape(value) + ((exdays==null) ? "" : "; expires="+exdate.toUTCString());
    document.cookie=c_name + "=" + c_value;
  }

  function getCookie(c_name) {
    var i,x,y;
    var ARRcookies=document.cookie.split(";");

    for (i=0;i<ARRcookies.length;i++) {
      x=ARRcookies[i].substr(0,ARRcookies[i].indexOf("="));
      y=ARRcookies[i].substr(ARRcookies[i].indexOf("=")+1);

      x=x.replace(/^\s+|\s+$/g,"");
      if (x==c_name) {
        return unescape(y);
      }
    }
  }

  function checkCookie() {
    var parent_id = getCookie("parent_id");
    if (parent_id != null && parent_id!="") {
      $("#"+parent_id).children().show();
    }
  }
});


/*******************************************************************************
 * Extendendo o JQuery para Trabalhar bem com o REST. (Incluindo suporte aos métodos "PUT"  e "DELETE"
 * */
function _ajax_request(url, data, callback, type, method) {
  if (jQuery.isFunction(data)) {
    callback = data;
    data = {};
  }
  return jQuery.ajax({
    type: method,
    url: url,
    data: data,
    success: callback,
    dataType: type
  });
}

jQuery.extend({
  put: function(url, data, callback, type) {
    return _ajax_request(url, data, callback, type, 'PUT');
  },
  delete_: function(url, data, callback, type) {
    return _ajax_request(url, data, callback, type, 'DELETE');
  }
});

/* Exibindo mensagens (flash_message) via javascript */
function flash_message(msg, css_class, div_to_show) {
  if(typeof div_to_show == "undefined")
    div_to_show = "flash_message_wrapper"
  erase_flash_messages();
  var html = '<div id="flash_message" class="' + css_class + '"><span>' + msg + '</span></div>';
  $("."+div_to_show).append(html);
}

/* Limpando mensagens existentes */
function erase_flash_messages() {
  if ($('#flash_message'))  
    $('#flash_message').remove();
}

/**
 * Deleta um objeto retirando sua tr da tabela
 * Apresenta msg (notice, alert) como flash messages
 */
$.fn.nice_delete = function(options) {
  var tr = $(this).parents('tr');
  if (typeof(options) == "undefined")
    options = {}

  if (typeof(options.success) == "undefined")
    options.success = function(data) {
      if (typeof(data.notice) != "undefined")
        flash_message(data.notice, 'notice');
      tr.fadeOut().remove();
    }

  if (typeof(options.error) == "undefined")
    options.error = function(data) {
      var data = $.parseJSON(data.responseText);
      if (typeof(data.alert) != "undefined")
        flash_message(data.alert, 'alert');
    }

  $.ajax({
    method: "DELETE",
    url: $(this).data("link-delete"),
    success: options.success,
    error: options.error
  });

  return this;
}
