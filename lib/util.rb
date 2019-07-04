class Util

  def self.make_canvass(answers,mapping)
    {
      canvass: {
        action_date: Time.now.to_json,
        contact_type: "spoke",
        success: true
      },
      add_answers: self.map_canvass(answers,mapping)
    }
  end

  def self.make_psh_person(person)
    psh_person= person.slice('given_name','family_name','phone_numbers','email_addresses')
    unless psh_person['email_addresses']
      psh_person['email_addresses']=[
        {
          address: [
            person['given_name'],
            '.',
            person['family_name'],
            '@',
            'fake.osdi.info'
          ].join.downcase
        }
      ]
    end
    psh_person
  end

  def self.make_psh(person)
    {
      person: make_psh_person(person)
    }
  end

  def self.map_canvass(osdi_answers, question_mapping)
    add_answers=osdi_answers.map do |osdi_answer|
      spoke_question_url=osdi_answer['osdi:question']._url

      mapper=question_mapping.find {|qm| qm['spoke_question_url']==spoke_question_url}
      van_question_url=mapper.dig('van_question_url')

      spoke_response=osdi_answer['responses'][0]
      van_response=mapper.dig('spoke_van_response_map',spoke_response)

      puts "A: #{'%-10s' % van_response} Q: #{mapper['comment'] || mapper['van_question_url']}"

      {
        question: van_question_url,
        responses: [ van_response ]
      }
    end

    add_answers
  end
end