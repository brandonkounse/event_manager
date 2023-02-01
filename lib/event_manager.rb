# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def peak_reg_hours(time, peak)
  t = Time.strptime(time, '%m/%d/%y %H:%M')
  peak[t.hour] += 1
end

def peak_reg_day(day, peak)
  d = Date.strptime(day, '%m/%d/%y')
  peak[d.strftime('%a')] += 1
end

def clean_phone_numbers(phone)
  phone.to_s.gsub!(/[^\d]/, '')
  case phone.length
  when 10
    phone
  when 11
    phone.start_with?('1') ? phone.slice!(1..-1) : 'bad number'
  else
    'bad number'
  end
end

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

peak_hours = Hash.new(0)
peak_weekday = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone = clean_phone_numbers(row[:homephone])
  time = peak_reg_hours(row[:regdate], peak_hours)
  day = peak_reg_day(row[:regdate], peak_weekday)
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end
