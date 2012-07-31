require 'rubygems'
require 'aws-sdk'
require 'time'
require 'date'

SNAPSHOT_VERSION=0.2

class EC2snapshot
	attr_accessor :retention

	def initialize(access_key_id, secret_access_key)
		@ec2 = AWS::EC2.new(
		    :access_key_id => access_key_id,
		    :secret_access_key => secret_access_key)
		@region = @ec2.regions["us-west-1"]
		@retention = 7
		puts "Program initializing..."
		puts "REGION=#{@region.name}"
		puts "RETENTION=#{@retention}"
		puts "PROGRAM VER=#{SNAPSHOT_VERSION}"
	end

	def auto_snapshot(instance_id)
		print "\n"*3
		puts "Checking instance #{instance_id}..."
		instance = @region.instances[instance_id]
		if instance.exists?
			puts "Instance exists, tag[name]=#{instance.tags.Name}"
			print "\n"*1
			recycle_snapshot instance
			print "\n"*1
			take_snapshot instance
		else
			puts "Instance does not exist!!"
		end
	end
	
	def recycle_snapshot(instance)
		puts "Checking snapshot retention..."
		@region.snapshots.filter('tag:from_instance', instance.id).each{ | snapshot |
			if snapshot.tags.expire_time.nil?
				puts "Snapshot #{snapshot.id} has null expire_time. Please check!!"
				next
			end

			expire_date = Date.parse(snapshot.tags.expire_time)
			date_today = Date.today
			retention = snapshot.tags.retention
			if expire_date <= date_today
				puts "Deleting snapshot #{snapshot.id}: rentention=#{retention}, expire_date=#{expire_date}"
				snapshot.delete
			else
				puts "Keep snapshot #{snapshot.id}: rentention=#{retention}, expire_date=#{expire_date}"
			end
		}
	end
		
	def take_snapshot(instance)
		instance_name = (instance.tags.Name.nil? ? instance.id : "#{instance.tags.Name}(#{instance.id})")
		instance.block_device_mappings.each {|device, attachment|
			puts "Creating snapshot for volume #{attachment.volume.id} on #{device}..."
			snapshot = attachment.volume.create_snapshot("Auto-snapshot #{instance_name}")
			snapshot.tag('Name', :value => "Auto-snapshot")
			snapshot.tag('from_instance', :value => instance.id)
			snapshot.tag('start_time', :value => Time.now.to_i)
			snapshot.tag('type', :value => 'auto')	
			snapshot.tag('retention', :value => @retention)	
			snapshot.tag('expire_time', :value => (Time.now + 3600*24*@retention).to_s)
			snapshot.tag('volume_id', :value => attachment.volume.id)
			snapshot.tag('version', :value => SNAPSHOT_VERSION)
			puts "Done. Snapshot ID: #{snapshot.id}"
		}
	end

	def region=(value)
		puts "!! Setting region from #{@region.name} to #{value}"
		@region = @ec2.regions[value]
	end
end
