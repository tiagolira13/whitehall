def extract_supporting_page(supporting_page, index)
  %|

##Appendix #{index+1}: #{supporting_page.title}

$CTA
This was a supporting detail page of the main policy document.
$CTA

#{supporting_page.body.gsub(/^(\s*[#]{2,})/, '\1#')}
|
end

def list_supporting_pages(supporting_pages)
  supporting_pages.map { |sp| "* #{sp.title}" }.join("\n")
end

gds_user = User.find_by!(name: "GDS Inside Government Team")

# Policy.published.each do |policy|
[Policy.find(444520)].each do |policy|

  title = "2010 to 2015 Conservative and Liberal democrat coalition policy: #{policy.title}"

  summary = policy.summary

  combined_body = policy.body

  supporting_pages = policy.supporting_pages.published
  supporting_pages.each_with_index do |supporting_page, index|
    combined_body += extract_supporting_page(supporting_page, index)
  end

  html_attachment = HtmlAttachment.new(
    title: title,
    ordering: 0,
    govspeak_content: GovspeakContent.new(
      body: combined_body,
      manually_numbered_headings: false,
    ),
  )

  policy_paper = Publication.new(
    title: title,
    summary: summary,
    body: list_supporting_pages(supporting_pages),
    publication_type_id: PublicationType::PolicyPaper.id,
    first_published_at: DateTime.new(2015, 3, 27, 6, 0, 0), # 6am, 27 March 2015
    political: true,
    creator: gds_user,
    alternative_format_provider: policy.lead_organisations.first,
  )

  [
    :lead_organisations,
    :supporting_organisations,
    :topics,
    :topical_events,
    :nation_inapplicabilities,
    :role_appointments,
    :fact_check_requests,
    :world_locations,
    :related_documents,
    :specialist_sectors,
  ].each do |association|
    policy_paper.send("#{association}=".to_sym, policy.send(association))
  end

  if policy_paper.save
    puts %{Created policy paper ##{policy_paper.id} "#{policy_paper.title}" from policy ##{policy.id}}

    policy_paper.attachments << html_attachment
    supporting_pages.map(&:attachments).flatten.uniq.each_with_index do |attachment, index|
      puts %{-- Adding attachment "#{attachment.html? ? 'HTML' : attachment.filename}"}

      existing_attachment = attachment.deep_clone

      # Reset attachment ordering, accounting for the HTML attachment
      existing_attachment.ordering = index + 1

      policy_paper.attachments << existing_attachment
    end
  else
    puts %{Failed to create policy paper from policy ##{policy.id} "#{policy_paper.title}"}
    policy_paper.errors.full_messages.each do |error|
      puts %{-- #{error}}

      puts %{---- #{policy_paper.body}} if error =~ /invalid formatting/

      if error =~ /Attachments/
        policy_paper.attachments.each do |attachment|
          puts %{---- #{attachment.errors.full_messages.join(',')}}
        end
      end
    end
  end
end
