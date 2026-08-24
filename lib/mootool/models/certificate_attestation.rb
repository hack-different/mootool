module MooTool::Models
  class CertificateAttestation
    def initialize(**kwargs)
      @props = kwargs
      @subject = kwargs.delete(:subject)
    end

    def to_tree
      MooTool::Helpers::TreeNode.new(@subject.ai,[], type: "Certificate Attestaion", properties: @props)
    end
  end
end