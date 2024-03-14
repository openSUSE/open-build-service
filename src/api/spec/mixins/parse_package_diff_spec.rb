RSpec.describe ParsePackageDiff do
  let(:instance_with_parse_package_diff_support) do
    fake_instance = double('Fake Instance with ParsePackageDiff')
    fake_instance.extend(ParsePackageDiff)
    fake_instance
  end

  describe '#sorted_filenames_from_sourcediff' do
    context 'with one file' do
      subject { instance_with_parse_package_diff_support.sorted_filenames_from_sourcediff(package_diff).first }

      let(:filename) { 'my_filename' }
      let(:package_diff) do
        "<sourcediff key='461472c75f0df9421a89f528417e72eb'>
          <old project='home:Admin' package='test' rev='4' srcmd5='61c8de91f59df43c9ffd1fa9b4a3f055' />
          <new project='home:Admin' package='test' rev='5' srcmd5='ca37dc90f6fd88f63db2ac9f1fc5c41c' />
          <files>
            <file state='changed'>
              <old name='#{filename}' md5='f00a43bbe6d74b350577e5bce2ea5ff7' size='42' />
              <new name='#{filename}' md5='3fd7513ed78f95e2be1bb211369bbea3' size='10' />
              <diff lines='1'># the diff</diff>
            </file>
          </files>
          <issues>
          </issues>
        </sourcediff>"
      end

      it 'contains the old filename' do
        result = { 'project' => 'home:Admin', 'package' => 'test', 'rev' => '4', 'srcmd5' => '61c8de91f59df43c9ffd1fa9b4a3f055' }
        expect(subject['old']).to eq(result)
      end

      it 'contains the new filename' do
        result = { 'project' => 'home:Admin', 'package' => 'test', 'rev' => '5', 'srcmd5' => 'ca37dc90f6fd88f63db2ac9f1fc5c41c' }
        expect(subject['new']).to eq(result)
      end

      it { expect(subject['filenames']).to eq([filename]) }
      it { expect(subject['files'][filename]['state']).to eq('changed') }
      it { expect(subject['files'][filename]['old']).to eq('name' => filename, 'md5' => 'f00a43bbe6d74b350577e5bce2ea5ff7', 'size' => '42') }
      it { expect(subject['files'][filename]['new']).to eq('name' => filename, 'md5' => '3fd7513ed78f95e2be1bb211369bbea3', 'size' => '10') }
      it { expect(subject['files'][filename]['diff']).to eq('lines' => '1', '_content' => '# the diff') }
    end

    context 'with more than one file' do
      subject { instance_with_parse_package_diff_support.sorted_filenames_from_sourcediff(package_diff).first }

      let(:package_diff) do
        '<sourcediff key="461472c75f0df9421a89f528417e72eb">
          <old project="home:Admin" package="test" rev="4" srcmd5="61c8de91f59df43c9ffd1fa9b4a3f055" />
          <new project="home:Admin" package="test" rev="5" srcmd5="ca37dc90f6fd88f63db2ac9f1fc5c41c" />
          <files>
            <file state="changed">
              <new name="bb_file" md5="3fd7513ed78f95e2be1bb211369bbea3" size="10" />
            </file>
            <file state="changed">
              <new name="aa_file" md5="3fd7513ed78f95e2be1bb211369bbea3" size="10" />
            </file>
            <file state="changed">
              <new name="aa.spec" md5="3fd7513ed78f95e2be1bb211369bbea3" size="10" />
            </file>
            <file state="changed">
              <new name="bb.spec" md5="3fd7513ed78f95e2be1bb211369bbea3" size="10" />
            </file>
            <file state="changed">
              <new name="aa.changes" md5="3fd7513ed78f95e2be1bb211369bbea3" size="10" />
            </file>
            <file state="changed">
              <new name="bb.changes" md5="3fd7513ed78f95e2be1bb211369bbea3" size="10" />
            </file>
            <file state="changed">
              <new name="aa.patch" md5="3fd7513ed78f95e2be1bb211369bbea3" size="10" />
            </file>
            <file state="changed">
              <new name="bb.dif" md5="3fd7513ed78f95e2be1bb211369bbea3" size="10" />
            </file>
            <file state="changed">
              <new name="cc.diff" md5="3fd7513ed78f95e2be1bb211369bbea3" size="10" />
            </file>
          </files>
          <issues>
          </issues>
        </sourcediff>'
      end

      it 'orders the filenames by type' do
        # changes files, spec files, patch files followed by all other files
        expect(subject['filenames']).to eq(['aa.changes', 'bb.changes', 'aa.spec', 'bb.spec', 'aa.patch', 'bb.dif', 'cc.diff', 'aa_file', 'bb_file'])
      end
    end

    context 'with issues' do
      subject { instance_with_parse_package_diff_support.sorted_filenames_from_sourcediff(package_diff).first['issues'] }

      let!(:package_diff) do
        <<~XML
          <sourcediff key='461472c75f0df9421a89f528417e72eb'>
            <old project='home:Admin' package='test' rev='4' srcmd5='61c8de91f59df43c9ffd1fa9b4a3f055' />
            <new project='home:Admin' package='test' rev='5' srcmd5='ca37dc90f6fd88f63db2ac9f1fc5c41c' />
            <files>
            </files>
            <issues>
              <issue name="#{issue.name}" tracker="#{issue_tracker.name}" label="#{issue.label}" />
              <issue name="#{deleted_issue.name}" tracker="#{issue_tracker.name}" label="#{deleted_issue.label}" state="deleted" />
              <issue tracker="without name" label="empty" />
            </issues>
          </sourcediff>
        XML
      end

      let(:issue_tracker) { IssueTracker.first }
      let(:issue) { create(:issue, issue_tracker: issue_tracker) }
      let(:deleted_issue) { create(:issue, name: 1234, issue_tracker: issue_tracker) }

      it { expect(subject[issue.label][:name]).to eq(issue.name) }
      it { expect(subject[issue.label][:tracker]).to eq(issue_tracker.name) }

      it { expect(subject[:empty]).to be_nil }
      it { expect(subject[deleted_issue.label][:name]).to eq(deleted_issue.name) }
    end
  end
end
