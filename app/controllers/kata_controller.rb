
require 'Approval'
require 'CodeOutputParser'
require 'FileHashDiffer'

class KataController < ApplicationController
  
  def edit
    @kata = Kata.new(root_dir, id)
    @avatar = Avatar.new(@kata, params[:avatar])
    @tab = @kata.language.tab    
    @visible_files = @avatar.visible_files
    @new_files = { }
    @files_to_remove = [ ]
    @traffic_lights = @avatar.traffic_lights
    @output = @visible_files['output']
    @title = id[0..5] + ' ' + @avatar.name + ' code' 
  end

  def run_tests    
    incoming_hashes = params[:file_hashes_incoming]
    outgoing_hashes = params[:file_hashes_outgoing]
    #Rails.logger.debug('FILE_HASHES_INCOMING:' + incoming_hashes.inspect);
    #Rails.logger.debug('FILE_HASHES_OUTGOING:' + outgoing_hashes.inspect);    
    delta = FileHashDiffer.diff(incoming_hashes, outgoing_hashes)
    
    @kata   = Kata.new(root_dir, id)
    @avatar = Avatar.new(@kata, params[:avatar])
    visible_files = received_files
    previous_files = visible_files.keys
    
    visible_files.delete('output')
    @output = @avatar.sandbox.test(delta, visible_files)
    visible_files['output'] = @output
    
    Approval::add_text_files_created_in_run_tests(@avatar.sandbox.dir, visible_files)
    Approval::delete_text_files_deleted_in_run_tests(@avatar.sandbox.dir, visible_files)
    
    language = @kata.language    
    traffic_light = CodeOutputParser::parse(language.unit_test_framework, @output)
    traffic_light[:time] = make_time(Time.now)
    @traffic_lights = @avatar.save_run_tests(visible_files, traffic_light)

    @new_files = visible_files.select {|filename, content| ! previous_files.include?(filename)}
    @files_to_remove = previous_files.select {|filename| ! @avatar.visible_files.keys.include?(filename)}
    
    @visible_files = @avatar.visible_files

    respond_to do |format|
      format.js if request.xhr?
    end      
  end
      
  def help_dialog
    @avatar_name = params[:avatar_name]
    render :layout => false
  end
      
  def fork_dialog
    render :layout => false
  end
  
private

  def received_files
    seen = { }
    (params[:file_content] || {}).each do |filename,content|
      # Cater for windows line endings from windows browser
      seen[filename] = content.gsub(/\r\n/, "\n")  
    end
    seen
  end

end


