require 'securerandom'
require 'property-list'
require 'fileutils'
require 'mini_magick'

module Stomostu
  Thumb_BB   = '272x153'
  Preview_BB = '796x448'
  
  class Project
    attr_reader :meta, :frames
    
    # path:: the base directory of the project
    def initialize(dir, name: 'New Project')
      @dir = dir
      if Dir.exist?(dir)
        @meta, @frames = ['stopmotion.meta', 'frames.meta'].map { |file|
          path = File.join(dir, file)
          File.exist?(path) or raise("Invalid path: “#{path}” missing!")
          PropertyList.load(File.read(path))
        }
      else
        Dir.mkdir(dir)
        time = Time.now.to_f

        uid = generate_uid
        @meta = {
          "CurrentFrameIndex"          => 1,
          # this works, if we add at least one frame image
          "META_RECORD_THUMB_FRAME_ID" => uid, 
          "ProductVersion"             => 6.0,
          "RecordDateCreated"          => time,
          "RecordDateModified"         => time,
          "RecordFPS"                  => 5,
          "RecordName"                 => name,
          "RecordNumberOfFrames"       => 1
        }

        @frames = {
          "FRAMELIST_INFO"    => "Framelist, (c)2010-13 Cateater, LLC",
          "FRAMELIST_VERSION" => 4.0,
          "FRAMELIST_DATA"    => [
            {
              "DURATION"                  => 1,
              "FRAME_ID"                  => uid,
              "FRAME_TYPE"                => 1,
              "IS_FRAME_PAUSED_FOR_AUDIO" => false,
              "UID"                       => uid            
            }
          ]
        }

      end
    end

    def add_frame(file, thumb: nil, preview: nil)
      uid = current_uid
      
      frame_f   = File.join(@dir, 'frame-'+uid+'.jpg')
      thumb_f   = File.join(@dir, 'thumb-'+uid+'.jpg')
      preview_f = File.join(@dir, 'preview-'+uid+'.jpg')
      
      link_or_copy(file, frame_f)
      
      if thumb
        link_or_copy(thumb, thumb_f)
      else
        img = MiniMagick::Image.open(file)
        img.resize(Thumb_BB)
        img.write(thumb_f)
        img.destroy!
      end
      
      if preview
        link_or_copy(preview, thumb_f)
      else
        img = MiniMagick::Image.open(file)
        img.resize(Preview_BB)
        img.write(preview_f)
        img.destroy!
      end
      
      add_frame_entry          
    end
    
    def link_or_copy(src, dest)
      begin
        FileUtils.ln(src, dest)
      rescue Errno::EXDEV
        warn "could not link “#{src}”, copying!"
        FileUtils.cp(src, dest)
      end
    end
    
    # Add a new entry to the frame list
    def add_frame_entry
      list = @frames["FRAMELIST_DATA"]
      last = list.last
      last["FRAME_TYPE"] = 0
      uid = generate_uid
      list << {
        "DURATION"                  => 1,
        "FRAME_ID"                  => uid,
        "FRAME_TYPE"                => 1,
        "IS_FRAME_PAUSED_FOR_AUDIO" => false,
        "UID"                       => uid
      }
      @meta["RecordNumberOfFrames"] += 1
      @frames
    end
    
    def current_uid
      @frames["FRAMELIST_DATA"].last["UID"]
    end
    
    def save
      File.write(File.join(@dir, 'stopmotion.meta'),
                 PropertyList.dump_xml(@meta))
      File.write(File.join(@dir, 'frames.meta'),
                 PropertyList.dump_xml(@frames))
    end
    
    def name
      @meta['RecordName']
    end
    
    def name=(n)
      @meta['RecordName'] = n
    end
    
    
    def generate_uid
      SecureRandom.uuid
    end
  end
end
    
