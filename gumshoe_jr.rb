require 'sinatra'
require 'sinatra/config_file'
require 'haml'
require 'rsolr-ext'
require 'thin'
require './lib/time.rb'
require './lib/login.rb'
require './lib/log.rb'
require './lib/abstract.rb'
require './lib/facet.rb'
require 'sinatra/flash'

include TimeModule
include EriAuth
include EriLog
include Abstract
include Facet

v = "Electronic Records Index [0.3.0a]"
title = "Manuscripts and Archives Division: Electronic Records Index"
enable :sessions

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :expire_after => 12000, # In seconds
                           :secret => 'd32908e75160962571c7ef3ea6b4865755a2ae6b'
                           
configure do
  set :server, :thin
end

config_file './conf/eri.yml'
solr = RSolr.connect :url => settings.solr

def get_or_post(path, opts={}, &block)
  get(path, opts, &block)
  post(path, opts, &block)
end

get '/' do
  if(session['login'] != true)
    redirect "/login"
  end
  
  @version = v
  @page = "Electronic Records Index" 
  @cols = Facet.get_collection_hash()
  
  haml :index
end


get "/login" do
  @version = v
  @title = title
  @page = "Login to ERI"
  haml :login
end

#administrative functions
get "/logout" do
  session["login"] = nil
  session["user"] = nil
  flash[:notice] = "You have been logged out"
  redirect "/"
end

post '/authenticate' do
  login = params[:name]
  password = params[:password]
  result = EriAuth.test_login(login, password)
  
  if result == true then 
    session["login"] = true
    session["user"] = login
    redirect "/"
  else
    flash[:error] = "Login failed"
    redirect "/"
  end
end

#controllers w/views
get_or_post '/results' do
  
  if(session['login'] != true)
    redirect "/login"
  end
  @cName = params[:cName]
  @page = "Search Results" 
  @q = params[:query]
  @qt = params[:qType]
  @start = params[:start].to_i
  @version = v
  
  EriLog.log_search(session['user'], @qt, @q) 
  
  if @qt == "full text" then
    @query = "text:" << @q
  else
    @query = ""
    @query << @qt
    @query << ":" << @q
  end
  
  if(session["limit"] != nil) then
    response = solr.get 'select', :params => {
      :q => @query,
      :fq => "cid:" << session['limit'],
      :start=> @start,
      :rows=>20
    }
  else
    response = solr.get 'select', :params => {
      :q => @query,
      :start=> @start,
      :rows=>20
    }
  end

  
  
  @result = response
  @facets = Facet.get_collection_hash()
  @fields = {"collection" => "cName", "component" => "series", "disk id" => "did", "file type" => "fType", "size" => "fSize", 
    "original filename" => "accessfilename", "mod date" => "mDate", "language" => "language"} 
  
  @links = {"collection" => "cid", "component" => "component", "disk" => "did"}
  @tm = TimeModule
  haml :results
  
end

get '/component' do
  
  if(session['login'] != true)
    redirect "/login"
  end
  
  @compId = '"' << params[:compId] << '"'
  @page = "Component Display" 
  
  response = solr.get 'select', :params => {
    :q=>"componentIdentifier:" << @compId,
    :start=>0,
    :rows=>2000
  }
  @result = response
  @version = v
  @names = Hash.new
  @orgs = Hash.new
  @locs = Hash.new
  @tm = TimeModule
  
  response['response']['docs'].each do |doc|
  	
  	if doc['names'] then
    	doc['names'].each do |name|
    	  name = name.tr("'", "")
    	  name = name.tr('"', '')
        if @names.has_key? name then
          @names[name] = @names[name] + 1
        else
          @names[name] = 1
        end
    	end
    end
  	
  	if doc['orgs'] then
    	doc['orgs'].each do |org|
    	  org = org.tr("'", "")
    	  org = org.tr('"', '')
        if @orgs.has_key? org then
          @orgs[org] = @orgs[org] + 1
        else
          @orgs[org] = 1
        end
    	end
    end
    
    if doc['locs'] then
      doc['locs'].each do |loc|
    	  loc = loc.tr("'", "")
    	  loc = loc.tr('"', '')
        if @locs.has_key? loc then
          @locs[loc] = @locs[loc] + 1
        else
          @locs[loc] = 1
        end
    	end
  	end
  end

  haml :component
end

get '/disk' do
  
  if(session['login'] != true)
    redirect "/login"
  end
  
  @page = "Media Display" 
  @did = params[:did]
  @cname = params[:cname]
  @version = v
  
  response = solr.get 'select', :params => {
    :q=>"diskId:" << @did,
    :start=>0,
    :rows=>2000
  }
  
  @names = Hash.new
  @orgs = Hash.new
  @locs = Hash.new
  response['response']['docs'].each do |doc|
  	
  	if doc['names'] then
    	doc['names'].each do |name|
    	  name = name.tr("'", "")
    	  name = name.tr('"', '')
        if @names.has_key? name then
          @names[name] = @names[name] + 1
        else
          @names[name] = 1
        end
    	end
    end
  	
  	if doc['orgs'] then
    	doc['orgs'].each do |org|
    	  org = org.tr("'", "")
    	  org = org.tr('"', '')
        if @orgs.has_key? org then
          @orgs[org] = @orgs[org] + 1
        else
          @orgs[org] = 1
        end
    	end
    end
    
    if doc['locs'] then
      doc['locs'].each do |loc|
    	  loc = loc.tr("'", "")
    	  loc = loc.tr('"', '')
        if @locs.has_key? loc then
          @locs[loc] = @locs[loc] + 1
        else
          @locs[loc] = 1
        end
    	end
  	end
  end

  @result = response
  @tm = TimeModule
  haml :disk
end

get '/collection' do
  
  if(session['login'] != true)
    redirect "/login"
  end
  
  @version = v
  @page = "Collection Display" 
  @colId = params[:cId]

  response = solr.get 'select', :params => {
    :q=>"colId:" << @colId,
    :start=>0,
    :rows=>2000,
    :fl => "componentTitle, parentComponentTitle, colName, diskId, componentIdentifier"
  }

  @components = SortedSet.new
  @media = SortedSet.new
  @cName
  @abstract = Abstract.get_abstract(@colId)
  response['response']['docs'].each do |doc|
    @components.add (doc['componentIdentifier'] << "|" << doc['componentTitle'])
    @media.add doc['diskId']
    @colName = doc['colName']
  end
  
  haml :collection
  
end

get '/file' do
  
  if(session['login'] != true)
    redirect "/login"
  end
  
  @page = "File Display" 
  @id = params[:id]
  @fields = {"id" => "id", "filename" => "filename", "file type" => "fType", "size" => "fSize", "original filename" => "accessfilename", "last modification date" => "mDate", "language" => "language", "collection" => "cName", "series" => "series", "disk" => "did", "path" => "path"}
  @links = {"collection" => "cid", "series" => "series", "disk" => "did"}
  @version = v
  @tm = TimeModule
  response = solr.get 'select', :params => {
    :q=>"id:" << @id,
    :start=>0,
    :rows=>50
  }
  
  EriLog.log_file(session['user'], @id) 
  @version = v
  @result = response
  @tm = TimeModule
  haml :file
end

get '/path' do
  
  if(session['login'] != true)
    redirect "/login"
  end
  
  @version = v
  @page = "Path Display" 
  @path = params["path"]
  haml :path
end

get '/about' do
  
  if(session['login'] != true)
    redirect "/login"
  end
  @version = v
  @page = "About"
  haml :about
end 

get '/limit' do
  session["limit"] = params[:cid]
  redirect "/results?query=#{params[:query]}&qType=#{params[:qType]}&cName=#{params[:cName]}"
end

get '/session' do
  session
end

get '/remove' do
  session["limit"] = nil
  redirect "/results?query=#{params[:query]}&qType=#{params[:qType]}"
end

get '/admin' do
  if session['admin'] == false
    flash[:error] = "You do not have permission to access admin pages"
    redirect "/"
  end
  @version = v
  @page = "Administration"
  haml :admin
end